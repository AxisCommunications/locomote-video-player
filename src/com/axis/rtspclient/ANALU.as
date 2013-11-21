package com.axis.rtspclient {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;
  import flash.net.NetStream;

  import com.axis.rtspclient.RTP;

  /* Assembler of NAL units */
  public class ANALU extends EventDispatcher
  {
    private var initialTime:uint = 0;
    private var nalu:NALU = null;

    public function ANALU()
    {
    }

    public function onRTPPacket(pkt:RTP):void
    {
      if (0 === initialTime) {
        initialTime = pkt.timestamp;
      }

      if (pkt.pt != 97) {
        return;
      }

      var data:ByteArray = pkt.getPayload();

      var nalhdr:uint = data.readUnsignedByte();
      var naltype:uint = nalhdr & 0x1F;

      var isIDR:Boolean;
      var timestamp:uint = pkt.timestamp - initialTime;

      if (26 >= naltype) {
        //ExternalInterface.call(HTTPClient.jsEventCallbackName, "Single packet NALU complete. Dispatching.");
        /* This RTP package is a single NALU, dispatch and forget */
        isIDR = (naltype === 5); // 5 = IDR, 1 = Non-IDR
        dispatchEvent(new NALU(data, isIDR, timestamp));
        return;
      }

      var nalfrag:uint = data.readUnsignedByte();
      var nfstart:uint = (nalfrag & 0x80) >>> 7;
      var nfend:uint   = (nalfrag & 0x40) >>> 6;
      var nftype:uint  = nalfrag & 0x1F;

      isIDR = (nftype === 5); // 5 = IDR, 1 = Non-IDR

      if (null === nalu) {
        nalu = new NALU(data, isIDR, timestamp);
      } else {
        nalu.appendData(data);
      }

      if (1 === nfend) {
        //ExternalInterface.call(HTTPClient.jsEventCallbackName, "Fragmented NALU complete. Dispatching.");
        dispatchEvent(nalu);
        nalu = null;
      }
    }
  }
}
