package com.axis.mjpegclient {

  import flash.events.ErrorEvent;
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.net.Socket;
  import flash.utils.ByteArray;

  import com.axis.Logger;
  import com.axis.ErrorManager;
  import com.axis.http.request;

  [Event(name="image",type="flash.events.Event")]
  [Event(name="connect",type="flash.events.Event")]
  [Event(name="error",type="flash.events.Event")]

  public class Handle extends EventDispatcher {

    private var urlParsed:Object;
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

    public function Handle(urlParsed:Object) {
      this.urlParsed = urlParsed;
      this.buffer = new ByteArray();
      this.dataBuffer = new ByteArray();
      this.socket = new Socket();
      this.socket.timeout = 5000;
      this.socket.addEventListener(Event.CONNECT, onConnect);
      this.socket.addEventListener(Event.CLOSE, onClose);
      this.socket.addEventListener(ProgressEvent.SOCKET_DATA, onHttpHeaders);
      this.socket.addEventListener(IOErrorEvent.IO_ERROR, onError);
      this.socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
    }

    private function onError(e:ErrorEvent):void {
      disconnect();
      dispatchEvent(new Event("IOError:" + e.errorID));
    }

    public function disconnect():void {
      if (!socket.connected) {
        return;
      }

      socket.close();
      image = null;
      buffer = null;
      dispatchEvent(new Event("disconnect"));
    }

    public function stop():void {
      disconnect();
    }

    public function connect():void {
      if (socket.connected) {
        disconnect();
      }

      Logger.log('MJPEGClient: connecting to', urlParsed.host + ':' + urlParsed.port);
      socket.connect(urlParsed.host, urlParsed.port);
    }

    private function onConnect(event:Event):void {
      buffer = new ByteArray();
      dataBuffer = new ByteArray();

      headers.length = 0;
      parseHeaders = true;
      parseSubheaders = true;
      socket.writeUTFBytes("GET " + urlParsed.urlpath + " HTTP/1.0\r\n");
      socket.writeUTFBytes("Host: " + urlParsed.host + ':' + urlParsed.port + "\r\n");
      socket.writeUTFBytes("Accept: multipart/x-mixed-replace\r\n");
      socket.writeUTFBytes("User-Agent: Locomote\r\n");
      socket.writeUTFBytes("\r\n");
    }

    private function onClose(e:Event):void {
      // Security error is thrown if this line is excluded
      socket.close();
    }

    private function onHttpHeaders(event:ProgressEvent):void {
      var parsed:* = request.readHeaders(socket, dataBuffer);
      if (false === parsed) {
        return;
      }

      if (200 !== parsed.code) {
        ErrorManager.dispatchError(parsed.code);
        disconnect();
        return;
      }

      if (!/^multipart\/x-mixed-replace/.test(parsed.headers['content-type'])) {
        ErrorManager.dispatchError(829);
        disconnect();
        return;
      }

      this.socket.removeEventListener(ProgressEvent.SOCKET_DATA, onHttpHeaders);
      this.socket.addEventListener(ProgressEvent.SOCKET_DATA, onImageData);

      if (0 < this.dataBuffer.bytesAvailable) {
        this.onImageData(event);
      }
    }

    private function onImageData(event:ProgressEvent):void {
      socket.readBytes(dataBuffer, dataBuffer.length);

      if (parseSubheaders) {
        var parsed:* = request.readHeaders(socket, dataBuffer);
        if (false === parsed) {
          return;
        }

        this.clen = parsed.headers['content-length'];
        parseSubheaders = false;
      }

      findImage();

      if (this.clen < this.dataBuffer.bytesAvailable) {
        onImageData(event);
      }
    };

    private function findImage():void {
      if (this.dataBuffer.bytesAvailable < this.clen + 2) {
        return;
      }

      image = new ByteArray()
      dataBuffer.readBytes(image, 0, clen + 2);

      var copy:ByteArray = new ByteArray();
      dataBuffer.readBytes(copy, 0);
      dataBuffer = copy;

      dispatchEvent(new Event("image"));
      clen = 0;
      parseSubheaders = true;
    }
  }
}
