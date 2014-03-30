package com.axis.rtspclient {

  import flash.events.ProgressEvent;
  import flash.events.EventDispatcher;
  import flash.utils.ByteArray;
  import flash.net.Socket;
  import mx.utils.Base64Encoder;
  import flash.external.ExternalInterface;

  import com.axis.rtspclient.ByteArrayUtils;
  import com.axis.rtspclient.FLVMux;
  import com.axis.rtspclient.RTP;
  import com.axis.rtspclient.SDP;
  import com.axis.http.url;

  public class RTSPClient extends EventDispatcher {
    private static var STATE_INITIAL:int       = 1<<0;
    private static var STATE_DESCRIBE_SENT:int = 1<<1;
    private static var STATE_DESCRIBE_RCVD:int = 1<<2;
    private static var STATE_SETUP:int         = 1<<3;
    private static var STATE_PLAY_SENT:int     = 1<<4;
    private static var STATE_PLAYING:int       = 1<<5;
    private static var STATE_TEARDOWN_SENT:int = 1<<6;
    private static var STATE_TEARDOWN_RCVD:int = 1<<7;

    private var state:int = STATE_INITIAL;

    private var getChannel:Socket;
    private var postChannel:Socket;

    private var sdp:SDP;
    private var flvmux:FLVMux;
    private var analu:ANALU;
    private var aaac:AAAC;

    private var urlParsed:Object;
    private var cSeq:uint = 1;
    private var session:String;
    private var contentBase:String;
    private var interleaveChannelIndex:uint = 0;
    private var base64encoder:Base64Encoder = new Base64Encoder();

    private var headers:ByteArray = new ByteArray();
    private var getChannelData:ByteArray = new ByteArray();
    private var contentLength:int = -1;
    private var rtpLength:int = -1;
    private var channel:int = -1;
    private var tracks:Array;

    public function RTSPClient(getChannel:Socket, postChannel:Socket, urlParsed:Object) {
      this.getChannel = getChannel;
      this.postChannel = postChannel;
      this.urlParsed = urlParsed;
      this.sdp = new SDP();
      this.analu = new ANALU();
      this.aaac = new AAAC(sdp);
    }

    public function start():void {
      getChannel.addEventListener(ProgressEvent.SOCKET_DATA, onGetData);
      sendRequest(describeReq());
      state = STATE_DESCRIBE_SENT;
    }

    private function requestReset():void
    {
      var copy:ByteArray = new ByteArray();
      getChannelData.readBytes(copy);
      getChannelData.clear();

      copy.readBytes(getChannelData);

      headers = new ByteArray();
      contentLength = -1;
      rtpLength     = -1;
      channel       = -1;
    }

    private function readRequest(oHeaders:ByteArray, oBody:ByteArray):Boolean
    {
      getChannel.readBytes(getChannelData);

      if (-1 === contentLength) {
        var headerEndPosition:int = ByteArrayUtils.indexOf(getChannelData, '\r\n\r\n');
        if (-1 === headerEndPosition) {
          /* We don't have full header yet */
          return false;
        }

        getChannelData.readBytes(headers, 0, headerEndPosition + 4);

        var headersString:String = headers.toString();
        var matches:Array = headersString.match(/Content-Length: ([0-9]+)/i);
        if (matches === null) {
          /* No content length, request finished here */
          headers.readBytes(oHeaders);
          requestReset();
          return true;
        }

        contentLength = parseInt(matches[1]);
      }

      if (getChannelData.bytesAvailable >= contentLength) {
        headers.readBytes(oHeaders);
        getChannelData.readBytes(oBody, 0, contentLength);

        requestReset();
        return true;
      }

      return false;
    }

    private function onGetData(event:ProgressEvent):void {
      var headers:ByteArray = new ByteArray(), body:ByteArray = new ByteArray();

      if (!readRequest(headers, body)) {
        return;
      }

      switch (state) {
      case STATE_INITIAL:
        ExternalInterface.call(HTTPClient.jsEventCallbackName, "STATE_INITIAL");

        break;
      case STATE_DESCRIBE_SENT:
        ExternalInterface.call(HTTPClient.jsEventCallbackName, "STATE_DESCRIBE_SENT");

        state = STATE_DESCRIBE_RCVD;

        if (!sdp.parse(body)) {
          ExternalInterface.call(HTTPClient.jsEventCallbackName, "ERROR", "Failed to parse SDP file");
          return;
        }

        var cbmatch:Array = headers.toString().match(/Content-Base: (.*)\r\n/);
        contentBase = cbmatch[1];
        tracks = sdp.getMediaBlockList();

        state = STATE_SETUP;
        /* Fall through, it's time for setup */
      case STATE_SETUP:
        ExternalInterface.call(HTTPClient.jsEventCallbackName, "STATE_SETUP");

        var headerString:String = headers.toString();
        var matches:Array = headerString.match(/Session: ([^;\s]+)[;\s]{1}/);
        if (null !== matches) {
          session = matches[1];
        }


        if (0 !== tracks.length) {
          /* More tracks we must setup before playing */
          var block:Object = tracks.shift();
          sendRequest(setupReq(block));
          return;
        }

        /* All tracks setup and ready to go! */
        sendRequest(playReq());
        state = STATE_PLAY_SENT;
        break;

      case STATE_PLAY_SENT:

        ExternalInterface.call(HTTPClient.jsEventCallbackName, "STATE_PLAY_SENT");
        state = STATE_PLAYING;

        this.flvmux = new FLVMux(this.sdp);

        getChannel.removeEventListener(ProgressEvent.SOCKET_DATA, onGetData);
        getChannel.addEventListener(ProgressEvent.SOCKET_DATA, onPlayData);

        addEventListener("VIDEO_PACKET", analu.onRTPPacket);
        addEventListener("AUDIO_PACKET", aaac.onRTPPacket);
        analu.addEventListener(NALU.NEW_NALU, flvmux.onNALU);
        aaac.addEventListener(AACFrame.NEW_FRAME, flvmux.onAACFrame);
        break;
      }
    }

    private function onPlayData(event:ProgressEvent):void
    {
      getChannel.readBytes(getChannelData, getChannelData.length);

      if (-1 == rtpLength && 0x24 === getChannelData[0]) {
        /* This is the beginning of a new RTP package */
        getChannelData.readByte();
        channel   = getChannelData.readByte();
        rtpLength = getChannelData.readShort();
      }

      if (getChannelData.bytesAvailable < rtpLength) {
        /* The complete RTP package is not here yet, wait for more data */
        return;
      }

      var pkgData:ByteArray = new ByteArray();

      getChannelData.readBytes(pkgData, 0, rtpLength);

      if (channel === 0 || channel === 2) {
        /* We're discarding the RTCP counter parts for now */
        var rtppkt:RTP = new RTP(pkgData, sdp);
        dispatchEvent(rtppkt);
      }

      requestReset();

      if (0 < getChannelData.bytesAvailable) {
        onPlayData(event);
      }
    }

    private function describeReq():String {
      return getCommandHeader("DESCRIBE", urlParsed.urlpath) +
             getCSeqHeader() +
             getUserAgentHeader() +
             "Accept: application/sdp\r\n" +
             "\r\n";
    }

    private function setupReq(block:Object):String {
      var interleavedChannels:String = interleaveChannelIndex++ + "-" + interleaveChannelIndex++;

      var p:String = url.isAbsolute(block.control) ? block.control : contentBase + block.control;
      return getCommandHeader("SETUP", p) +
             getCSeqHeader() +
             getUserAgentHeader() +
             getSessionHeader() +
             "Transport: RTP/AVP/TCP;unicast;interleaved=" + interleavedChannels + "\r\n" +
             "Date: " + new Date().toUTCString() + "\r\n" +
             "\r\n";
    }


    private function playReq():String {
      return getCommandHeader("PLAY", contentBase) +
             getCSeqHeader() +
             getUserAgentHeader() +
             getSessionHeader() +
             "\r\n";
    }

    private function teardownReq():String {
      return getCommandHeader("TEARDOWN", contentBase) +
             getCSeqHeader() +
             getUserAgentHeader() +
             getSessionHeader() +
             "\r\n";
    }

    private function base64encode(str:String):String {
      base64encoder.reset();
      base64encoder.insertNewLines = false;
      base64encoder.encode(str);
      return base64encoder.toString();
    }

    private function getCommandHeader(command:String, url:String):String {
      return command + " " + url + " RTSP/1.0\r\n";
    }

    private function getCSeqHeader():String {
      return "CSeq: " + (++cSeq) + "\r\n";
    }

    private function getUserAgentHeader():String {
      return "User-Agent: Slush\r\n";
    }

    private function getSessionHeader():String {
      return (session ? ("Session: " + session + "\r\n") : "");
    }

    private function sendRequest(request:String):void {
      postChannel.writeUTFBytes(base64encode(request));
      postChannel.flush();
    }
  }
}
