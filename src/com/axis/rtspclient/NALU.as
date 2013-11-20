package com.axis.rtspclient {

  import flash.external.ExternalInterface;
  import flash.events.Event;
  import flash.utils.ByteArray;

  public class NALU extends Event
  {
    public static const NEW_NALU:String = "NEW_NALU";

    private var data:ByteArray;
    public var isIDR:Boolean;
    public var timestamp:uint;
    public var bodySize:uint;

    public function NALU(data:ByteArray, isIDR:Boolean, timestamp:uint)
    {
      super(NEW_NALU);

      this.data      = data;
      this.isIDR     = isIDR;
      this.timestamp = timestamp;
      this.bodySize  = data.bytesAvailable;
    }

    public function appendData(idata:ByteArray):void
    {
      ByteArrayUtils.appendByteArray(data, idata);
      this.bodySize  = data.bytesAvailable;
    }

    public function getPayload():ByteArray
    {
      return data;
    }
  }
}
