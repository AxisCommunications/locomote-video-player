package com.axis.rtspclient {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

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
      var data:ByteArray = pkt.getPayload();

      var nalhdr:uint = data.readUnsignedByte();

      var nri:uint     = nalhdr & 0x60;
      var naltype:uint = nalhdr & 0x1F;

      if (27 >= naltype) {
        /* This RTP package is a single NALU, dispatch and forget */
        dispatchEvent(new NALU(naltype, nri, data, pkt.getTimestampMS()));
        return;
      }

      /* This is a fragmented NAL unit, FU-A if 28 and FU-B if 29 */

      if (28 != naltype) {
        /* Only support for FU-A at this time */
        trace('Unsupported NAL unit, type: ' + naltype);
        return;
      }

      var nalfrag:uint = data.readUnsignedByte();
      var nfstart:uint = (nalfrag & 0x80) >>> 7;
      var nfend:uint   = (nalfrag & 0x40) >>> 6;
      var nftype:uint  = nalfrag & 0x1F;

      if (null === nalu) {
        /* Create a new NAL unit from multiple fragmented NAL units */
        nalu = new NALU(nftype, nri, data, pkt.getTimestampMS());
      } else {
        /* We've already created the NAL unit, append current data */
        nalu.appendData(data);
      }

      if (1 === nfend) {
        dispatchEvent(nalu);
        nalu = null;
      }
    }
  }
}
