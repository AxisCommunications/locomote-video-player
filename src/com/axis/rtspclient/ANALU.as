package com.axis.rtspclient {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;
  import flash.net.NetStream;

  import com.axis.rtspclient.RTP;
  import com.axis.rtspclient.ByteArrayUtils;

  /* Assembler of NAL units */
  public class ANALU extends EventDispatcher
  {
    private var nalu:NALU = null;

    public function ANALU()
    {
    }

    public function onRTPPacket(pkt:RTP):void
    {
      if (pkt.pt != 97) {
        return;
      }

      var data:ByteArray = pkt.getPayload();

      var nalhdr:uint = data.readUnsignedByte();

      var naltype:uint = nalhdr & 0x1F;

      var isIDR:Boolean;

      if (26 >= naltype) {
        /* This RTP package is a single NALU, dispatch and forget */
        isIDR = (naltype === 5); // 5 = IDR, 1 = Non-IDR
        dispatchEvent(new NALU(data, isIDR, pkt.getTimestampMS()));
        return;
      }

      var nalfrag:uint = data.readUnsignedByte();
      var nfstart:uint = (nalfrag & 0x80) >>> 7;
      var nfend:uint   = (nalfrag & 0x40) >>> 6;
      var nftype:uint  = nalfrag & 0x1F;

      isIDR = (nftype === 5); // 5 = IDR, 1 = Non-IDR

      if (null === nalu) {
        nalu = new NALU(data, isIDR, pkt.getTimestampMS());
      } else {
        nalu.appendData(data);
      }

      if (1 === nfend) {
        dispatchEvent(nalu);
        nalu = null;
      }
    }
  }
}
