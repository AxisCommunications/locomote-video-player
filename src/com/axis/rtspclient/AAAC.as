package com.axis.rtspclient {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

  import com.axis.rtspclient.RTP;
  import com.axis.rtspclient.ByteArrayUtils;

  /* Assembler of AAC frames */
  public class AAAC extends EventDispatcher
  {
    private var sdp:SDP;

    public function AAAC(sdp:SDP)
    {
      this.sdp = sdp;
    }

    public function onRTPPacket(pkt:RTP):void
    {
      var media:Object = sdp.getMediaBlockByPayloadType(pkt.pt);
      var sizeLength:uint = parseInt(media.fmtp['SizeLength']);
      var indexLength:uint = parseInt(media.fmtp['IndexLength']);

      var data:ByteArray = pkt.getPayload();


      var auHeadersLengthInBits:uint = data.readUnsignedShort();
      if (16 !== auHeadersLengthInBits) {
        throw new Error('No support for non HBR headers.');
      }

      var aacPktLen:uint = data.readUnsignedShort() >> indexLength; /* skip delta */

      dispatchEvent(new AACFrame(data, pkt.getTimestampMS()));
    }
  }
}
