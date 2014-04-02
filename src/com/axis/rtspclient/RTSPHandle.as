package com.axis.rtspclient {

  import flash.net.Socket;
  import flash.events.ProgressEvent;
  import flash.events.Event;
  import flash.utils.ByteArray;
  import mx.utils.Base64Encoder;

  public class RTSPHandle implements IRTSPHandle {
    private var channel:Socket;
    private var urlParsed:Object;
    private var datacb:Function = null;
    private var connectcb:Function = null;

    public function RTSPHandle(iurl:Object)
    {
      this.urlParsed = iurl;

      channel = new Socket();
      channel.timeout = 5000;
      channel.addEventListener(Event.CONNECT, channelConnect);
      channel.addEventListener(ProgressEvent.SOCKET_DATA, function():void {
        if (null !== datacb) datacb();
      });
    }

    private function channelConnect(event:Event):void
    {
      trace('channel connect');
      if (null !== connectcb) connectcb();
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

    public function onData(cb:Function):void {
      this.datacb = cb;
    }

    public function onConnect(cb:Function):void {
      this.connectcb = cb;
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
  }
}
