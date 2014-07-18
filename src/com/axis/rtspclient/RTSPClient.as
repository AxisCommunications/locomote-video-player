package com.axis.rtspclient {

  import flash.events.EventDispatcher;
  import flash.events.Event;
  import flash.utils.ByteArray;
  import flash.net.Socket;
  import flash.net.NetConnection;
  import flash.net.NetStream;
  import flash.media.Video;
  import mx.utils.StringUtil;

  import com.axis.rtspclient.FLVMux;
  import com.axis.rtspclient.RTP;
  import com.axis.rtspclient.SDP;
  import com.axis.http.url;
  import com.axis.http.request;
  import com.axis.http.auth;
  import com.axis.IClient;
  import com.axis.ClientEvent;

  public class RTSPClient extends EventDispatcher implements IClient {
    [Embed(source = "../../../../VERSION", mimeType = "application/octet-stream")] private var Version:Class;
    private var userAgent:String;

    private static const STATE_INITIAL:uint  = 1 << 0;
    private static const STATE_OPTIONS:uint  = 1 << 1;
    private static const STATE_DESCRIBE:uint = 1 << 2;
    private static const STATE_SETUP:uint    = 1 << 3;
    private static const STATE_PLAY:uint     = 1 << 4;
    private static const STATE_PLAYING:uint  = 1 << 5;
    private static const STATE_PAUSE:uint    = 1 << 6;
    private static const STATE_PAUSED:uint   = 1 << 7;
    private static const STATE_TEARDOWN:uint = 1 << 8;

    private var state:int = STATE_INITIAL;
    private var handle:IRTSPHandle;
    private var ns:NetStream;
    private var video:Video;

    private var sdp:SDP = new SDP();
    private var flvmux:FLVMux;

    private var urlParsed:Object;
    private var cSeq:uint = 1;
    private var session:String;
    private var contentBase:String;
    private var interleaveChannelIndex:uint = 0;

    private var methods:Array = [];
    private var data:ByteArray = new ByteArray();
    private var rtpLength:int = -1;
    private var rtpChannel:int = -1;
    private var tracks:Array;

    private var authState:String = "none";
    private var authOpts:Object = {};
    private var digestNC:uint = 1;

    public function RTSPClient(video:Video, urlParsed:Object, handle:IRTSPHandle) {
      this.userAgent = "Slush " + StringUtil.trim(new Version().toString());
      this.state = STATE_INITIAL;
      this.handle = handle;
      this.video = video;
      this.urlParsed = urlParsed;

      handle.addEventListener('data', this.onData);
    }

    public function start():Boolean {
      var self:RTSPClient = this;
      handle.addEventListener('connected', function():void {
        if (state !== STATE_INITIAL) {
          trace('Cannot start unless in initial state.');
          return;
        }

        /* If the handle closes, take care of it */
        handle.addEventListener('closed', self.onClose);

        if (0 === self.methods.length) {
          /* We don't know the options yet. Start with that. */
          sendOptionsReq();
        } else {
          /* Already queried the options (and perhaps got unauthorized on describe) */
          sendDescribeReq();
        }
      });

      var nc:NetConnection = new NetConnection();
      nc.connect(null);
      this.ns = new NetStream(nc);
      dispatchEvent(new ClientEvent(ClientEvent.NETSTREAM_CREATED, { ns : this.ns }));
      video.attachNetStream(this.ns);

      handle.connect();
      return true;
    }

    public function pause():Boolean {
      if (state !== STATE_PLAYING) {
        trace('Unable to pause a stream if not playing.');
        return false;
      }

      try {
        sendPauseReq();
      } catch (err:Error) {
        trace("Unable to pause: " + err.message);
        return false;
      }

      return true;
    }

    public function resume():Boolean {
      if (state !== STATE_PAUSED) {
        trace('Unable to resume a stream if not paused.');
        return false;
      }

      sendPlayReq();
      return true;
    }

    public function stop():Boolean {
      if (state < STATE_PLAY) {
        trace('Unable to stop if we never reached play.');
        return false;
      }
      sendTeardownReq();
      return true;
    }

    private function onClose(event:Event):void {
      if (state === STATE_TEARDOWN) {
        this.ns.dispose();
        dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
      } else {
        trace('RTSPClient: Handle unexpectedly closed.');
      }
    }

    private function onData(event:Event):void {
      if (0 < data.bytesAvailable) {
        /* Determining byte have already been read. This is a continuation */
      } else {
        /* Read the determining byte */
        handle.readBytes(data, data.position, 1);
      }

      switch(data[0]) {
        case 0x52:
          /* ascii 'R', start of RTSP */
          onRTSPCommand();
          break;

        case 0x24:
          /* ascii '$', start of interleaved packet */
          onInterleavedData();
          break;

        default:
          trace('Unknown determining byte:', '0x' + data[0].toString(16), '. Stopping stream.');
          stop();
          break;
      }
    }

    private function requestReset():void {
      var copy:ByteArray = new ByteArray();
      data.readBytes(copy);
      data.clear();
      copy.readBytes(data);

      rtpLength  = -1;
      rtpChannel = -1;
    }

    private function readRequest(oBody:ByteArray):* {
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
        state = STATE_INITIAL;
        data = new ByteArray();
        handle.reconnect();
        return false;
      }

      if (parsed.headers['content-length']) {
        if (data.bytesAvailable < parsed.headers['content-length']) {
          return false;
        }

        /* RTSP commands contain no heavy body, so it's safe to read everything */
        data.readBytes(oBody, 0, parsed.headers['content-length']);
      }

      requestReset();
      return parsed;
    }

    private function onRTSPCommand():void {
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

      case STATE_OPTIONS:
        trace("RTSPClient: STATE_OPTIONS");
        this.methods = parsed.headers.public.split(/[ ]*,[ ]*/);
        sendDescribeReq();

        break;
      case STATE_DESCRIBE:
        trace("RTSPClient: STATE_DESCRIBE");

        if (!sdp.parse(body)) {
          trace("RTSPClient:Failed to parse SDP file");
          return;
        }

        contentBase = parsed.headers['content-base'];
        tracks = sdp.getMediaBlockList();
        trace('SDP contained ' + tracks.length + ' track(s). Calling SETUP for each.');

        if (0 === tracks.length) {
          trace('No tracks in SDP file.');
          return;
        }

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
        break;

      case STATE_PLAY:
        trace("RTSPClient: STATE_PLAY");
        state = STATE_PLAYING;

        if (this.flvmux) {
          /* If the flvmux have been initialized don't do it again.
             this is probably a resume after pause */
          break;
        }

        this.flvmux = new FLVMux(this.ns, this.sdp);
        var analu:ANALU = new ANALU();
        var aaac:AAAC = new AAAC(sdp);

        this.addEventListener("VIDEO_PACKET", analu.onRTPPacket);
        this.addEventListener("AUDIO_PACKET", aaac.onRTPPacket);
        analu.addEventListener(NALU.NEW_NALU, flvmux.onNALU);
        aaac.addEventListener(AACFrame.NEW_FRAME, flvmux.onAACFrame);
        break;

      case STATE_PLAYING:
        trace("RTSPClient: STATE_PLAYING");
        break;

      case STATE_PAUSE:
        trace("RTSPClient: STATE_PAUSE");
        state = STATE_PAUSED;
        break;

      case STATE_TEARDOWN:
        trace('RTSPClient: STATE_TEARDOWN');
        this.handle.disconnect();
        break;
      }

      if (0 < data.bytesAvailable) {
        onData(null);
      }
    }

    private function onInterleavedData():void {
      handle.readBytes(data, data.length);

      if (data.bytesAvailable < 4) {
        /* Not enough data even for interleaved header. Try again when
           more data is available */
        return;
      }

      if (-1 == rtpLength && 0x24 === data[0]) {
        /* This is the beginning of a new RTP package. We can't read data
           from buffer here, as we may not have enough for complete RTP packet
           and we need to be able to determine that this is an interleaved
           packet when `onData` is called again. */
        rtpChannel = data[1];
        rtpLength = data[2] << 8 | data[3];
      }

      if (data.bytesAvailable < rtpLength + 4) { /* add 4 for interleaved header */
        /* The complete RTP package is not here yet, wait for more data */
        return;
      }

      /* Discard the interleaved header. It was extracted previously. */
      data.readUnsignedInt();

      var pkgData:ByteArray = new ByteArray();
      data.readBytes(pkgData, 0, rtpLength);

      if (rtpChannel === 0 || rtpChannel === 2) {
        /* We're discarding the RTCP counter parts for now */
        var rtppkt:RTP = new RTP(pkgData, sdp);
        dispatchEvent(rtppkt);
      }

      requestReset();

      if (0 < data.bytesAvailable) {
        onData(null);
      }
    }

    private function supportCommand(command:String):Boolean {
      return (-1 !== this.methods.indexOf(command));
    }

    private function getSetupURL(block:Object = null):* {
      var sessionBlock:Object = sdp.getSessionBlock();
      if (url.isAbsolute(block.control)) {
        return block.control;
      } else if (url.isAbsolute(sessionBlock.control + block.control)) {
        return sessionBlock.control + block.control;
      } else if (url.isAbsolute(contentBase + block.control)) {
        /* Should probably check session level control before this */
        return contentBase + block.control;
      }

      trace('Can\'t determine track URL from ' +
            'block.control:' + block.control + ', ' +
            'session.control:' + sessionBlock.control + ', and ' +
            'content-base:' + contentBase);
      throw new Error('Unable to determine control URL.');
    }

    private function getControlURL():String {
      var sessCtrl:String = sdp.getSessionBlock().control;
      var u:String = sessCtrl;
      if (url.isAbsolute(u)) {
        return u;
      } else if ('*' === u) {
        return contentBase;
      } else {
        return contentBase + u; /* If content base is not set, this will be session control only only */
      }

      trace('Can\'t determine control URL from ' +
              'session.control:' + sessionBlock.control + ', and ' +
              'content-base:' + contentBase);
      throw new Error('Unable to determine control URL.');
    }

    private function sendOptionsReq():void {
      state = STATE_OPTIONS;
      var req:String =
        "OPTIONS * RTSP/1.0\r\n" +
        "CSeq: " + (++cSeq) + "\r\n" +
        "User-Agent: " + userAgent + "\r\n" +
        "\r\n";
      handle.writeUTFBytes(req);
    }

    private function sendDescribeReq():void {
      state = STATE_DESCRIBE;
      var u:String = 'rtsp://' + urlParsed.host + urlParsed.urlpath;
      var req:String =
        "DESCRIBE " + u + " RTSP/1.0\r\n" +
        "CSeq: " + (++cSeq) + "\r\n" +
        "User-Agent: " + userAgent + "\r\n" +
        "Accept: application/sdp\r\n" +
        auth.authorizationHeader("DESCRIBE", authState, authOpts, urlParsed, digestNC++) +
        "\r\n";
      handle.writeUTFBytes(req);
    }

    private function sendSetupReq(block:Object):void {
      state = STATE_SETUP;
      var interleavedChannels:String = interleaveChannelIndex++ + "-" + interleaveChannelIndex++;
      var setupUrl:String = getSetupURL(block);

      trace('Setting up track: ' + setupUrl);
      var req:String =
        "SETUP " + setupUrl + " RTSP/1.0\r\n" +
        "CSeq: " + (++cSeq) + "\r\n" +
        "User-Agent: " + userAgent + "\r\n" +
        (session ? ("Session: " + session + "\r\n") : "") +
        "Transport: RTP/AVP/TCP;unicast;interleaved=" + interleavedChannels + "\r\n" +
        auth.authorizationHeader("SETUP", authState, authOpts, urlParsed, digestNC++) +
        "Date: " + new Date().toUTCString() + "\r\n" +
        "\r\n";
      handle.writeUTFBytes(req);
    }

    private function sendPlayReq():void {
      /* Put the NetStream in 'Data Generation Mode'. Data is generated by FLVMux */
      this.ns.play(null);

      state = STATE_PLAY;
      dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));

      var req:String =
        "PLAY " + getControlURL() + " RTSP/1.0\r\n" +
        "CSeq: " + (++cSeq) + "\r\n" +
        "User-Agent: " + userAgent + "\r\n" +
        "Session: " + session + "\r\n" +
        auth.authorizationHeader("PLAY", authState, authOpts, urlParsed, digestNC++) +
        "\r\n";
      handle.writeUTFBytes(req);
    }

    private function sendPauseReq():void {
      if (-1 === this.supportCommand("PAUSE")) {
        throw new Error('Pause is not supported by server.');
      }

      state = STATE_PAUSE;

      /* NetStream must be closed here, otherwise it will think of this rtsp pause
         as a very bad connection and buffer a lot before playing again. Not
         excellent for live data. */
      this.ns.close();

      var req:String =
        "PAUSE " + getControlURL() + " RTSP/1.0\r\n" +
        "CSeq: " + (++cSeq) + "\r\n" +
        "User-Agent: " + userAgent + "\r\n" +
        "Session: " + session + "\r\n" +
        auth.authorizationHeader("PAUSE", authState, authOpts, urlParsed, digestNC++) +
        "\r\n";
      handle.writeUTFBytes(req);
    }

    private function sendTeardownReq():void {
      state = STATE_TEARDOWN;
      var req:String =
        "TEARDOWN " + getControlURL() + " RTSP/1.0\r\n" +
        "CSeq: " + (++cSeq) + "\r\n" +
        "User-Agent: " + userAgent + "\r\n" +
        "Session: " + session + "\r\n" +
        auth.authorizationHeader("TEARDOWN", authState, authOpts, urlParsed, digestNC++) +
        "\r\n";
      handle.writeUTFBytes(req);
    }
  }
}
