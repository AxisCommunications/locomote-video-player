package com.axis.mjpgplayer {

  import flash.events.ErrorEvent;
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.system.Security;
  import flash.external.ExternalInterface;
  import flash.display.LoaderInfo;

  import mx.utils.URLUtil;

  [Event(name="image",type="flash.events.Event")]
  [Event(name="connect",type="flash.events.Event")]
  [Event(name="error",type="flash.events.Event")]

  /**
   * Error codes:
   * 0: Socket or security errors
   * 1: Client side validation errors
   * 2: Server HTTP response errors
   * 3: Valid HTTP response (200), but invalid content
   */

  public class IPCam extends EventDispatcher {

    private var jsEventCallbackName:String = "console.log";
    private var socket:Socket = null;
    private var buffer:ByteArray = null;
    private var dataBuffer:ByteArray = null;
    private var url:String = "";
    private var params:Object;
    private var parseHeaders:Boolean = true;
    private var headers:Vector.<String> = new Vector.<String>();
    private var clen:int;
    private var parseSubheaders:Boolean = true;

    public var image:ByteArray = null;

    public function IPCam() {
      // Set up JS API
      ExternalInterface.marshallExceptions = true;
      ExternalInterface.addCallback("play", connect);
      ExternalInterface.addCallback("pause", disconnect);
      ExternalInterface.addCallback("stop", stop);
      ExternalInterface.addCallback("setEventCallbackName", setJsEventCallbackName);

      Security.allowDomain("*");
      Security.allowInsecureDomain("*");

      buffer = new ByteArray();
      dataBuffer = new ByteArray();
      socket = new Socket();
      socket.timeout = 5000;
      socket.addEventListener(Event.CONNECT, onSockConn);
      socket.addEventListener(Event.CLOSE, onClose);
      socket.addEventListener(ProgressEvent.SOCKET_DATA, onSockData);
      socket.addEventListener(IOErrorEvent.IO_ERROR, onError);
      socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
    }

    public function sendLoadedEvent():void {
      // Tell the external JS environent that we are ready to accept API calls
      ExternalInterface.call(jsEventCallbackName, 'loaded');
    }

    public function setJsEventCallbackName(jsEventCallbackName:String):void {
      this.jsEventCallbackName = jsEventCallbackName;
    }

    public function getJsEventCallbackName():String {
      return jsEventCallbackName;
    }

    private function onError(e:ErrorEvent):void {
      sendError(0, e.text);
    }

    private function sendError(errNo:Number = 0, msg:String = ""):void {
      disconnect();
      dispatchEvent(new Event("error"));
      ExternalInterface.call(jsEventCallbackName, "error", errNo, msg);
    }

    public function disconnect():void {
      if (socket.connected) {
        socket.close();
      }
      image = null;
      buffer = null;
      dispatchEvent(new Event("disconnect"));
    }

    public function stop():void {
      disconnect();
      dispatchEvent(new Event("clear"));
    }

    public function connect(url:String = null):void {
      disconnect();

      if (url != null) {
        this.url = url;
      }

      if (!URLUtil.isHttpURL(this.url)) {
        sendError(1, "Invalid Url");
        return;
      }

      socket.connect(URLUtil.getServerName(this.url), 80);
    }

    private function onSockConn(event:Event):void {
      buffer = new ByteArray();
      dataBuffer = new ByteArray();

      parseHeaders = true;
      socket.writeUTFBytes("GET " + url + " HTTP/1.0\r\n");
      socket.writeUTFBytes("Host: " + URLUtil.getServerName(url) + "\r\n");
      socket.writeUTFBytes("\r\n");
    }

    private function onClose(e:Event):void {
      // Security error is thrown if this line is excluded
      socket.close();
    }

    private function readline():Boolean {
      while (dataBuffer.bytesAvailable > 0) {
        var t:String = dataBuffer.readMultiByte(1, "us-ascii");
        if (t == "\r") {
          continue;
        }
        if (t == "\n") {
          return true;
        }
        buffer.writeMultiByte(t, "us-ascii");
      }

      return false;
    }

    private function getContentType():String {
      var content:String = "content-type: ";
      for each (var str:String in headers) {
        if (str.toLowerCase().indexOf(content) >= 0) {
          return str.substr(str.indexOf(content) + content.length).toLowerCase();
        }
      }
      return "";
    }

    private function onParseHeaders():Boolean {
      headers.length = 0;
      while (1) {
        var wholeLine:Boolean = readline();

        if (!wholeLine) {
          return false;
        }

        if (buffer.length == 0) {
          parseHeaders = false;
          break;
        }

        headers.push(buffer.toString());
        buffer.clear();
      }
      try {
        var arr:Array = headers[0].split(" ");
        if (arr[1] == "200") {
          var content:String = getContentType();
          if (content.indexOf("multipart/x-mixed-replace") >= 0) {
            dispatchEvent(new Event("connect"));
            return true;
          }
          throw(new Error("error"));
        } else {
          sendError(2, "Server retured error code " + arr[1] + ".");
        }
      }
      catch (e:Error) {
        sendError(3, "Invalid response received.");
      }
      return false;
    }

    private function onSockData(event:ProgressEvent):void {
      socket.readBytes(dataBuffer, dataBuffer.length);
      if (parseHeaders) {
        if (!onParseHeaders()) {
          return;
        }
      }
      if (parseSubheaders) {
        if (!parseSubHeader()) {
          return;
        }
      }
      findImage();
    }

    private function parseSubHeader():Boolean {
      while (parseSubheaders) {
        var wholeLine:Boolean = readline();

        if (!wholeLine) {
          return false;
        }

        if (buffer.length == 0) {
          break;
        }

        var subHeaders:Array = buffer.toString().split(": ");
        if ((subHeaders[0] as String).toLowerCase() == "content-length") {
          clen = subHeaders[1];
        }
        buffer.clear();
      }

      parseSubheaders = false;

      return true;
    }

    private function findImage():void {
      if (dataBuffer.bytesAvailable < clen + 2) {
        return;
      }

      image = new ByteArray()
      dataBuffer.readBytes(image, 0, clen + 2);
      //dataBuffer.readMultiByte(2, "us-ascii");    // Why is this not needed? Probably the cause of stability issues

      var copy:ByteArray = new ByteArray();
      dataBuffer.readBytes(copy, 0);
      dataBuffer = copy;

      dispatchEvent(new Event("image"));
      clen = 0;
      parseSubheaders = true;
    }

  }

}
