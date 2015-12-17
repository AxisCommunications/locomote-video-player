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

    public function NALU(ntype:uint, nri:uint, data:ByteArray, timestamp:uint) {
      super(NEW_NALU);

      this.data      = data;
      this.ntype     = ntype;
      this.nri       = nri;
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
      return 2 + 2 + 1 + data.bytesAvailable;
    }

    public function writeStream(output:ByteArray):void {
      output.writeUnsignedInt(data.bytesAvailable + 1); // NALU length + header
      output.writeByte((0x0 & 0x80) | (nri & 0x60) | (ntype & 0x1F)); // NAL header
      output.writeBytes(data, data.position);
    }

    public function getPayload():ByteArray {
      var payload:ByteArray = new ByteArray();
      data.position -= 1;
      data.readBytes(payload, 0, data.bytesAvailable);
      return payload;
    }
  }
}
