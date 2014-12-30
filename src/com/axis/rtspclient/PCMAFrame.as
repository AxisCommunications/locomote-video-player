package com.axis.rtspclient {
  import com.axis.rtspclient.ByteArrayUtils;
  import com.axis.rtspclient.RTP;

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

  /* Assembler of PCMA frames */
  public class PCMAFrame extends Event {
    public static const NEW_FRAME:String = "NEW_FRAME";

    private var data:ByteArray;
    public var timestamp:uint;

    public function PCMAFrame(data:ByteArray, timestamp:uint) {
      super(PCMAFrame.NEW_FRAME);
      this.data = data;
      this.timestamp = timestamp;
    }

    public function writeStream(output:ByteArray):void {
      output.writeBytes(data, data.position);
    }

    public function getPayload():ByteArray {
      return data;
    }
  }
}
