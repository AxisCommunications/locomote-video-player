package com.axis.rtspclient {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

  import com.axis.rtspclient.RTP;
  import com.axis.rtspclient.ByteArrayUtils;

  /* Assembler of AAC frames */
  public class AACFrame extends Event
  {
    public static const NEW_FRAME:String = "NEW_FRAME";

    private var data:ByteArray;
    public var timestamp:uint;

    public function AACFrame(data:ByteArray, timestamp:uint)
    {
      super(AACFrame.NEW_FRAME);
      this.data = data;
      this.timestamp = timestamp;
    }

    public function writeStream(output:ByteArray):void
    {
      output.writeBytes(data, data.position);
    }

    public function getPayload():ByteArray
    {
      return data;
    }
  }
}
