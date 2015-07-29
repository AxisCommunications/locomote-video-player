package com.axis.rtspclient {
  import com.axis.ClientEvent;
  import com.axis.ErrorManager;
  import com.axis.Logger;

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.net.Socket;
  import flash.utils.ByteArray;

  import mx.utils.Base64Encoder;

  public class RTSPoverTCPHandle extends EventDispatcher implements IRTSPHandle {
    private var channel:Socket;
    private var urlParsed:Object;

    public function RTSPoverTCPHandle(iurl:Object) {
      this.urlParsed = iurl;

      channel = new Socket();
      channel.timeout = 5000;
      channel.addEventListener(Event.CONNECT, onConnect);
      channel.addEventListener(ProgressEvent.SOCKET_DATA, onData);
      channel.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
      channel.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
    }

    public function writeUTFBytes(value:String):void {
      channel.writeUTFBytes(value);
      channel.flush();
    }

    public function sendRTCPPacket(data:ByteArray):void {
        // Add frame for RTCP over TCP
        var pkt:ByteArray = new ByteArray();
        pkt.writeByte(0x24);
        pkt.writeByte(0x01);
        var dataLength:uint = data.length;
        pkt.writeShort(dataLength);
        pkt.writeBytes(data);
        channel.writeBytes(pkt);
        channel.flush();
    }

    public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void {
      channel.readBytes(bytes, offset, length);
    }

    public function connect():void {
      channel.connect(urlParsed.host, urlParsed.port);
    }

    public function reconnect():void {
      channel.close();
      connect();
    }

    public function disconnect():void {
      channel.close();
      channel = null;

      /* should probably wait for close, but it doesn't seem to fire properly */
      dispatchEvent(new Event("closed"));
    }

    private function onConnect(event:Event):void {
      dispatchEvent(new Event("connected"));
    }

    private function onData(event:ProgressEvent):void {
      dispatchEvent(new Event("data"));
    }

    private function onIOError(event:IOErrorEvent):void {
      ErrorManager.dispatchError(732, [event.text]);
      dispatchEvent(new Event("closed"));
    }

    private function onSecurityError(event:SecurityErrorEvent):void {
      ErrorManager.dispatchError(731, [event.text]);
      dispatchEvent(new Event("closed"));
    }
  }
}
