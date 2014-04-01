package com.axis.rtspclient {

  import flash.net.Socket;
  import flash.events.ProgressEvent;
  import flash.utils.ByteArray;
  import mx.utils.Base64Encoder;

  public class RTSPoverHTTPHandle implements IRTSPHandle {
    private var getChannel:Socket;
    private var postChannel:Socket;
    private var base64encoder:Base64Encoder = new Base64Encoder();
    private var cb:Function = null;

    public function RTSPoverHTTPHandle(getChannel:Socket, postChannel:Socket)
    {
      this.getChannel = getChannel;
      this.postChannel = postChannel;
      this.getChannel.addEventListener(ProgressEvent.SOCKET_DATA, function():void {
        if (null !== cb) cb();
      });
    }

    private function base64encode(str:String):String {
      base64encoder.reset();
      base64encoder.insertNewLines = false;
      base64encoder.encode(str);
      return base64encoder.toString();
    }

    public function writeUTFBytes(value:String):void
    {
      postChannel.writeUTFBytes(base64encode(value));
      postChannel.flush();
    }

    public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void
    {
      getChannel.readBytes(bytes, offset, length);
    }

    public function onData(cb:Function):void {
      this.cb = cb;
    }
  }
}
