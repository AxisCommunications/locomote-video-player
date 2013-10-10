package com.axis.rtspclient {

  import flash.events.ProgressEvent;
  import flash.utils.ByteArray;
  import flash.net.Socket;
  import mx.utils.Base64Encoder;
  import flash.external.ExternalInterface;

  import com.axis.rtspclient.ByteArrayUtils;
  import com.axis.rtspclient.SDP;

  public class RTSPClient {
    private static var STATE_INITIAL:int       = 1<<0;
    private static var STATE_DESCRIBE_SENT:int = 1<<1;
    private static var STATE_DESCRIBE_RCVD:int = 1<<2;
    private static var STATE_SETUP_SENT:int    = 1<<3;
    private static var STATE_SETUP_RCVD:int    = 1<<4;
    private static var STATE_PLAY_SENT:int     = 1<<5;
    private static var STATE_PLAY_RCVD:int     = 1<<6;
    private static var STATE_TEARDOWN_SENT:int = 1<<7;
    private static var STATE_TEARDOWN_RCVD:int = 1<<8;

    private var state:int = STATE_INITIAL;

    private var getChannel:Socket;
    private var postChannel:Socket;

    private var sdp:SDP;

    private var url:String;
    private var jsEventCallbackName:String;
    private var cSeq:uint = 0;
    private var session:String;
    private var base64encoder:Base64Encoder = new Base64Encoder();

    private var headers:ByteArray = new ByteArray();
    private var getChannelData:ByteArray = new ByteArray();
    private var contentLength:int = -1;

    public function RTSPClient(getChannel:Socket, postChannel:Socket, url:String, jsEventCallbackName:String) {
      this.getChannel = getChannel;
      this.postChannel = postChannel;
      this.url = url;
      this.jsEventCallbackName = jsEventCallbackName;
      this.sdp = new SDP(jsEventCallbackName);
    }

    public function start():void {
      getChannel.addEventListener(ProgressEvent.SOCKET_DATA, onGetChannelData);
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
    }

    private function readRequest(oHeaders:ByteArray, oBody:ByteArray):Boolean
    {
      ExternalInterface.call(jsEventCallbackName, "reading request...");
      getChannel.readBytes(getChannelData);

      ExternalInterface.call(jsEventCallbackName, "contentLength: ", contentLength);
      if (-1 === contentLength) {
        var headerEndPosition:int = ByteArrayUtils.indexOf(getChannelData, '\r\n\r\n');
        if (-1 === headerEndPosition) {
          /* We don't have full header yet */
          ExternalInterface.call(jsEventCallbackName, "Not full request yet");
          return false;
        }

        ExternalInterface.call(jsEventCallbackName, "hep: ", headerEndPosition);
        ExternalInterface.call(jsEventCallbackName, "gcd: ", getChannelData);
        getChannelData.readBytes(headers, 0, headerEndPosition + 4);

        var headersString:String = headers.toString();
        var matches:Array = headersString.match(/Content-Length: ([0-9]+)/i);
        if (matches === null) {
          /* No content length, request finished here */
          ExternalInterface.call(jsEventCallbackName, headers);
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

    private function onGetChannelData(event:ProgressEvent):void {
      var headers:ByteArray = new ByteArray(), body:ByteArray = new ByteArray();
      var doHandle:Boolean = readRequest(headers, body);

      if (!doHandle) {
        return;
      }

      ExternalInterface.call(jsEventCallbackName, "headers:\n", headers.toString());
      ExternalInterface.call(jsEventCallbackName, "body:\n", body.toString());

      switch (state) {
      case STATE_INITIAL:
        ExternalInterface.call(jsEventCallbackName, "STATE_INITIAL");

        break;
      case STATE_DESCRIBE_SENT:
        ExternalInterface.call(jsEventCallbackName, "STATE_DESCRIBE_SENT");

        state = STATE_DESCRIBE_RCVD;
        if (!sdp.parse(body)) {
          ExternalInterface.call(jsEventCallbackName, "ERROR", "Failed to parse SDP file");
          return;
        }
        sendRequest(setupReq());
        state = STATE_SETUP_SENT;
        break;
      case STATE_SETUP_SENT:
        ExternalInterface.call(jsEventCallbackName, "STATE_SETUP_SENT");

        state = STATE_SETUP_RCVD;

        var headerString:String = headers.toString();
        var matches:Array = headerString.match(/Session: ([^;]+);/);
        if (null === matches) {
          ExternalInterface.call(jsEventCallbackName, "No session in SETUP reply");
        }
        session = matches[1];

        sendRequest(playReq());
        state = STATE_PLAY_SENT;
        break;

      case STATE_PLAY_SENT:
        ExternalInterface.call(jsEventCallbackName, "STATE_PLAY_SENT");

        ExternalInterface.call(jsEventCallbackName, headers.toString(), body.toString());
        state = STATE_PLAY_RCVD;
        break;
      }
    }

    private function describeReq():String {
      return getCommandHeader("DESCRIBE", url) +
             getCSeqHeader() +
             getUserAgentHeader() +
             "Accept: application/sdp\r\n" +
             "\r\n";
    }

    private function setupReq():String {
      return getCommandHeader("SETUP", sdp.getTrack()) +
             getCSeqHeader() +
             getUserAgentHeader() +
             "Transport: RTP/AVP/TCP;interleaved=0-1\r\n" +
             "\r\n";
    }


    private function playReq():String {
      return getCommandHeader("PLAY", sdp.getTrack()) +
             getCSeqHeader() +
             getUserAgentHeader() +
             "Session: " + session + "\r\n" +
             "\r\n";
    }

    private function base64encode(str:String):String {
      base64encoder.reset();
      base64encoder.encode(str);
      return base64encoder.toString();
    }

    private function getCommandHeader(command:String, url:String):String {
      return command + " " + url + " RTSP/1.0\r\n";
    }

    private function getCSeqHeader():String {
      return "CSeq: " + (cSeq++) + "\r\n";
    }

    private function getUserAgentHeader():String {
      return "User-Agent: Slush\r\n";
    }

    private function sendRequest(request:String):void {
      ExternalInterface.call(jsEventCallbackName, 'RTSPPOST:\n', request.toString());
      postChannel.writeUTFBytes(base64encode(request));
      postChannel.flush();
    }
  }
}
