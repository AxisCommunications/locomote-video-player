package com.axis.rtspclient {
  import flash.events.Event;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

  public class NALU extends Event {
    public static const NEW_NALU:String = "NEW_NALU";

    private var data:ByteArray;
    public var ntype:uint;
    public var nri:uint;
    public var timestamp:uint;
    public var bodySize:uint;

    public function NALU(data:ByteArray, timestamp:uint) {
      super(NEW_NALU);

      data.position  = 0;
      this.data      = data;
      this.nri       = data[0] & 0x60;
      this.ntype     = data[0] & 0x1F;
      this.timestamp = timestamp;
      this.bodySize  = data.bytesAvailable;
    }

    public function appendData(idata:ByteArray):void {
      ByteArrayUtils.appendByteArray(data, idata);
      this.bodySize = data.bytesAvailable;
    }

    public function isIDR():Boolean {
      return (5 === ntype);
    }

    public function writeSize():uint {
      return 2 + 2 + data.length;
    }

    public function writeStream(output:ByteArray):void {
      output.writeUnsignedInt(data.length); // NALU length + header
      output.writeBytes(data);
    }

    public function getPayload():ByteArray {
      var payload:ByteArray = new ByteArray();

      payload.writeBytes(data);
      payload.position = 0;

      return payload;
    }
  }
}
