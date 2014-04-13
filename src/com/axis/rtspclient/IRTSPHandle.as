package com.axis.rtspclient {

  import flash.events.IEventDispatcher;
  import flash.utils.ByteArray;
  import flash.net.Socket;

  public interface IRTSPHandle extends IEventDispatcher {
    function writeUTFBytes(value:String):void;
    function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void;
    function connect():void;
    function reconnect():void;
    function disconnect():void;
  }
}
