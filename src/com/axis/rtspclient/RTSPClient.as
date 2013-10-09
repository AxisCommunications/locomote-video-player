package com.axis.rtspclient {

  import flash.utils.ByteArray;
  import flash.net.Socket;
  import mx.utils.Base64Encoder;
  import flash.external.ExternalInterface;

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

    private var tracks:Vector.<String> = new Vector.<String>();

    private var url:String;
    private var jsEventCallbackName:String;
    private var cSeq:uint = 0;
    private var base64encoder:Base64Encoder = new Base64Encoder();

    public function RTSPClient(getChannel:Socket, postChannel:Socket, url:String, jsEventCallbackName:String) {
      this.getChannel = getChannel;
      this.postChannel = postChannel;
      this.url = url;
      this.jsEventCallbackName = jsEventCallbackName;
    }

    public function start():void {
      sendRequest(describeReq());
      state = STATE_DESCRIBE_SENT;
    }

    public function handle(data:ByteArray):void {
      ExternalInterface.call(jsEventCallbackName, "RTSPClient hanlde", data.toString());

      switch(state) {
        case STATE_INITIAL:
          break;
        case STATE_DESCRIBE_SENT:
          parseSDP(data);
          state = STATE_DESCRIBE_RCVD;
          if (tracks.length > 0) {
            sendRequest(setupReq(tracks.shift()));
            state = STATE_SETUP_SENT;
          } else {
            ExternalInterface.call(jsEventCallbackName, "error", "Failed to parse SDP file (no tracks found)");
          }
          break;
        case STATE_SETUP_SENT:
          // parse setup response?
          break;
      }
    }

    private function parseSDP(data:ByteArray):void {
      var dataString:String = data.toString();
      var matches:Array = dataString.match(/a=control:(.*)/g);
      for each (var match:String in matches) {
        tracks.push(match.replace("a=control:", ""));
      }
    }

    private function describeReq():String {
      return getCommandHeader("DESCRIBE", url) +
             getCSeqHeader() +
             getUserAgentHeader() +
             "Accept: application/sdp\r\n" +
             "\r\n";
    }

    private function setupReq(trackUrl:String):String {
      return getCommandHeader("SETUP", trackUrl) +
             getCSeqHeader() +
             getUserAgentHeader() +
             "Transport: RTP/AVP/TCP;interleaved=0-1\r\n" +
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
      return "User-Agent: Axis AMC\r\n";
    }

    private function sendRequest(request:String):void {
      postChannel.writeUTFBytes(base64encode(request));
      ExternalInterface.call(jsEventCallbackName, "POSTing", request);
      postChannel.flush();
    }
  }
}
