package com.axis.rtspclient {

  import flash.events.EventDispatcher;
  import flash.events.Event;
  import flash.utils.ByteArray;
  import flash.net.Socket;

  import com.axis.rtspclient.FLVMux;
  import com.axis.rtspclient.RTP;
  import com.axis.rtspclient.SDP;
  import com.axis.http.url;
  import com.axis.http.request;
  import com.axis.http.auth;

  public class RTSPClient extends EventDispatcher {
    private static var userAgent:String = "Slush 0.1";

    private static var STATE_INITIAL:int       = 1<<0;
    private static var STATE_DESCRIBE_SENT:int = 1<<1;
    private static var STATE_DESCRIBE_RCVD:int = 1<<2;
    private static var STATE_SETUP:int         = 1<<3;
    private static var STATE_PLAY_SENT:int     = 1<<4;
    private static var STATE_PLAYING:int       = 1<<5;
    private static var STATE_TEARDOWN_SENT:int = 1<<6;
    private static var STATE_TEARDOWN_RCVD:int = 1<<7;

    private var state:int = STATE_INITIAL;

    private var handle:IRTSPHandle;

    private var sdp:SDP;
    private var flvmux:FLVMux;
    private var analu:ANALU;
    private var aaac:AAAC;

    private var urlParsed:Object;
    private var cSeq:uint = 1;
    private var session:String;
    private var contentBase:String;
    private var interleaveChannelIndex:uint = 0;

    private var headers:ByteArray = new ByteArray();
    private var data:ByteArray = new ByteArray();
    private var rtpLength:int = -1;
    private var rtpChannel:int = -1;
    private var tracks:Array;

    private var authState:String = "none";
    private var authOpts:Object = {};
    private var digestNC:uint = 1;

    public function RTSPClient(handle:IRTSPHandle, urlParsed:Object) {
      this.handle = handle;
      this.urlParsed = urlParsed;
      this.sdp = new SDP();
      this.analu = new ANALU();
      this.aaac = new AAAC(sdp);
    }

    public function start():void {
      handle.addEventListener('data', onGetData);
      sendDescribeReq();
      state = STATE_DESCRIBE_SENT;
    }

    private function requestReset():void
    {
      var copy:ByteArray = new ByteArray();
      data.readBytes(copy);
      data.clear();

      copy.readBytes(data);

      headers = new ByteArray();
      rtpLength     = -1;
      rtpChannel    = -1;
    }

    private function readRequest(oBody:ByteArray):*
    {
      var parsed:* = request.readHeaders(handle, data);
      if (false === parsed) {
        return false;
      }

      if (401 === parsed.code) {
        /* Unauthorized, change authState and (possibly) try again */
        authOpts = parsed.headers['www-authenticate'];
        var newAuthState:String = auth.nextMethod(authState, authOpts);
        if (authState === newAuthState) {
          trace('GET: Exhausted all authentication methods.');
          trace('GET: Unable to authorize to ' + urlParsed.host);
          return false;
        }

        trace('RTSPClient: switching http-authorization from ' + authState + ' to ' + newAuthState);
        authState = newAuthState;
        data = new ByteArray();
        handle.reconnect();
        return false;
      }

      if (data.bytesAvailable < parsed.headers['content-length']) {
        return false;
      }

      data.readBytes(oBody, 0, parsed.headers['content-length']);
      requestReset();
      return parsed;
    }

    private function onGetData(ev:Event):void {
      var parsed:*, body:ByteArray = new ByteArray();

      if (false === (parsed = readRequest(body))) {
        return;
      }

      if (200 !== parsed.code) {
        trace('RTSPClient: Invalid RTSP response - ', parsed.code, parsed.message);
        return;
      }


      switch (state) {
      case STATE_INITIAL:
        trace("RTSPClient: STATE_INITIAL");

        break;
      case STATE_DESCRIBE_SENT:
        trace("RTSPClient: STATE_DESCRIBE_SENT");

        state = STATE_DESCRIBE_RCVD;

        if (!sdp.parse(body)) {
          trace("RTSPClient:Failed to parse SDP file");
          return;
        }

        if (!parsed.headers['content-base']) {
          trace('RTSPClient: no content-base in describe reply');
          return;
        }

        contentBase = parsed.headers['content-base'];
        tracks = sdp.getMediaBlockList();

        state = STATE_SETUP;
        /* Fall through, it's time for setup */
      case STATE_SETUP:
        trace("RTSPClient: STATE_SETUP");

        if (parsed.headers['session']) {
          session = parsed.headers['session'];
        }

        if (0 !== tracks.length) {
          /* More tracks we must setup before playing */
          var block:Object = tracks.shift();
          sendSetupReq(block);
          return;
        }

        /* All tracks setup and ready to go! */
        sendPlayReq();
        state = STATE_PLAY_SENT;
        break;

      case STATE_PLAY_SENT:

        trace("RTSPClient: STATE_PLAY_SENT");
        state = STATE_PLAYING;

        this.flvmux = new FLVMux(this.sdp);

        handle.removeEventListener("data", onGetData);
        handle.addEventListener("data", onPlayData);

        addEventListener("VIDEO_PACKET", analu.onRTPPacket);
        addEventListener("AUDIO_PACKET", aaac.onRTPPacket);
        analu.addEventListener(NALU.NEW_NALU, flvmux.onNALU);
        aaac.addEventListener(AACFrame.NEW_FRAME, flvmux.onAACFrame);
        break;
      }
    }

    private function onPlayData(ev:Event):void
    {
      handle.readBytes(data, data.length);

      if (-1 == rtpLength && 0x24 === data[0]) {
        /* This is the beginning of a new RTP package */
        data.readByte();
        rtpChannel   = data.readByte();
        rtpLength = data.readShort();
      }

      if (data.bytesAvailable < rtpLength) {
        /* The complete RTP package is not here yet, wait for more data */
        return;
      }

      var pkgData:ByteArray = new ByteArray();

      data.readBytes(pkgData, 0, rtpLength);

      if (rtpChannel === 0 || rtpChannel === 2) {
        /* We're discarding the RTCP counter parts for now */
        var rtppkt:RTP = new RTP(pkgData, sdp);
        dispatchEvent(rtppkt);
      }

      requestReset();

      if (0 < data.bytesAvailable) {
        onPlayData(ev);
      }
    }

    private function writeAuthorizationHeader(method:String):void
    {
      var a:String = '';
      switch (authState) {
        case "basic":
          a = auth.basic(this.urlParsed.user, this.urlParsed.pass) + "\r\n";
          break;

        case "digest":
          a = auth.digest(
            this.urlParsed.user,
            this.urlParsed.pass,
            method,
            authOpts.digestRealm,
            urlParsed.urlpath,
            authOpts.qop,
            authOpts.nonce,
            digestNC++
          );
          break;

        default:
        case "none":
          return;
      }

      handle.writeUTFBytes('Authorization: ' + a + "\r\n");
    }

    private function sendDescribeReq():void {
      handle.writeUTFBytes("DESCRIBE " + urlParsed.urlpath + " RTSP/1.0\r\n");
      handle.writeUTFBytes("CSeq: " + (++cSeq) + "\r\n");
      handle.writeUTFBytes("User-Agent: " + userAgent + "\r\n");
      handle.writeUTFBytes("Accept: application/sdp\r\n");
      writeAuthorizationHeader("DESCRIBE");
      handle.writeUTFBytes("\r\n");
    }

    private function sendSetupReq(block:Object):void {
      var interleavedChannels:String = interleaveChannelIndex++ + "-" + interleaveChannelIndex++;
      var p:String = url.isAbsolute(block.control) ? block.control : contentBase + block.control;

      handle.writeUTFBytes("SETUP " + p + " RTSP/1.0\r\n");
      handle.writeUTFBytes("CSeq: " + (++cSeq) + "\r\n");
      handle.writeUTFBytes("User-Agent: " + userAgent + "\r\n");
      handle.writeUTFBytes(session ? ("Session: " + session + "\r\n") : "");
      handle.writeUTFBytes("Transport: RTP/AVP/TCP;unicast;interleaved=" + interleavedChannels + "\r\n");
      writeAuthorizationHeader("SETUP");
      handle.writeUTFBytes("Date: " + new Date().toUTCString() + "\r\n");
      handle.writeUTFBytes("\r\n");
    }

    private function sendPlayReq():void {
      handle.writeUTFBytes("PLAY " + contentBase + " RTSP/1.0\r\n");
      handle.writeUTFBytes("CSeq: " + (++cSeq) + "\r\n");
      handle.writeUTFBytes("User-Agent: " + userAgent + "\r\n");
      handle.writeUTFBytes("Session: " + session + "\r\n");
      writeAuthorizationHeader("PLAY");
      handle.writeUTFBytes("\r\n");
    }

    private function sendTeardownReq():void {
      handle.writeUTFBytes("TEARDOWN" + contentBase + " RTSP/1.0\r\n");
      handle.writeUTFBytes("CSeq: " + (++cSeq) + "\r\n");
      handle.writeUTFBytes("User-Agent: " + userAgent + "\r\n");
      handle.writeUTFBytes("Session: " + session + "\r\n");
      writeAuthorizationHeader("TEARDOWN");
      handle.writeUTFBytes("\r\n");
    }
  }
}
