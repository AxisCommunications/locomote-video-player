package com.axis.rtspclient {
  import flash.utils.ByteArray;

  public interface IRTSPHandle {
    function writeUTFBytes(value:String):void;
    function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void;
    function onData(cb:Function):void;
  }
}
