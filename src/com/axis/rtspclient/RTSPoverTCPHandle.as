package com.axis.rtspclient {

  import flash.net.Socket;
  import flash.events.EventDispatcher;
  import flash.events.ProgressEvent;
  import flash.events.Event;
  import flash.utils.ByteArray;
  import mx.utils.Base64Encoder;

  public class RTSPoverTCPHandle extends EventDispatcher implements IRTSPHandle {
    private var channel:Socket;
    private var urlParsed:Object;

    public function RTSPoverTCPHandle(iurl:Object)
    {
      this.urlParsed = iurl;

      channel = new Socket();
      channel.timeout = 5000;
      channel.addEventListener(Event.CONNECT, function():void {
        dispatchEvent(new Event("connected"));
      });
      channel.addEventListener(ProgressEvent.SOCKET_DATA, function():void {
        dispatchEvent(new Event("data"));
      });
    }

    public function writeUTFBytes(value:String):void
    {
      channel.writeUTFBytes(value);
      channel.flush();
    }

    public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void
    {
      channel.readBytes(bytes, offset, length);
    }

    public function connect():void
    {
      channel.connect(urlParsed.host, urlParsed.port);
    }

    public function reconnect():void
    {
      channel.close();
      connect();
    }

    public function disconnect():void
    {
      channel.close();
    }
  }
}
