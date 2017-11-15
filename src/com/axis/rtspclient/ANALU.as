package com.axis.rtspclient {
  import com.axis.Logger;
  import com.axis.rtspclient.ByteArrayUtils;
  import com.axis.rtspclient.RTP;

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

  /* Assembler of NAL units */
  public class ANALU extends EventDispatcher {
    private static const NALTYPE_FU_A:uint = 28;
    private static const NALTYPE_FU_B:uint = 29;
    private static const SYNC_CODE_LEN:uint = 3;

    private var nalu:NALU = null;
    private var fragbuffer:ByteArray = new ByteArray();
    private var timestamp:uint;

    public function ANALU() {
    }

    public function onRTPPacket(pkt:RTP):void {
      var data:ByteArray = pkt.getPayload();

      timestamp = pkt.getTimestampMS();

      var nalhdr:uint	 = data.readUnsignedByte();
      var nri:uint     = nalhdr & 0x60;
      var naltype:uint = nalhdr & 0x1F;

      if (27 >= naltype && 0 < naltype) {
        /* This RTP package is a single NALU, dispatch and forget, 0 is undefined */
        var payload:ByteArray = new ByteArray();

        data.position -= 1; // include NAL header
        payload.writeBytes(data, data.position);
        dispatchEvent(new NALU(payload, timestamp));
        return;
      }

      if (NALTYPE_FU_A !== naltype && NALTYPE_FU_B !== naltype) {
        /* 30 - 31 is undefined, ignore those (RFC3984). */
        Logger.log('Undefined NAL unit, type: ' + naltype);
        return;
      }

      var nalfrag:uint = data.readUnsignedByte();
      var nfstart:uint = (nalfrag & 0x80) >>> 7;
      var nfend:uint   = (nalfrag & 0x40) >>> 6;
      var nftype:uint  = nalfrag & 0x1F;

      if (NALTYPE_FU_B === naltype) {
        var nfdon:uint = data.readUnsignedShort();
      }
      if (1 === nfstart) {
        var hdr:uint = (0x0 & 0x80) | (nri & 0x60) | (nftype & 0x1F);

        fragbuffer.clear();
        fragbuffer.writeByte(hdr); // prepend NAL header
      }

      fragbuffer.writeBytes(data, data.position);
      if (1 === nfend) {
        processBuffer();
      }
    }
    private function processBuffer():void {
      var usableLen:uint = fragbuffer.length - SYNC_CODE_LEN;
      var cur:uint = 1;
      var pcur:uint = 0;
			var pos:uint = 0;

      /** Find (00) 00 00 01 sync codes and emit NALs at them */
      for (cur = 1; cur < usableLen; cur) {
        pcur = cur;
        if ( fragbuffer[cur++] === 0x00
          && fragbuffer[cur++] === 0x00
          && (
            fragbuffer[cur] === 0x01
            || (
              fragbuffer[cur++] === 0x00
              && fragbuffer[cur] === 0x01
          ))
        ) {
          emitNalu(pos, pcur - pos);
          pos = ++cur;
        }
      }
      emitNalu(pos, fragbuffer.length - pos);
    }
    private function emitNalu(offset:uint, length:uint):void {
      var payload:ByteArray = new ByteArray();
      payload.writeBytes(fragbuffer, offset, length);

      dispatchEvent(new NALU(payload, timestamp));
    }
  }
}
