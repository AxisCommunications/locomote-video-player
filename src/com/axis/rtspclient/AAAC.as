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
      var sizeLength:uint = parseInt(media.fmtp['sizelength']);
      var indexLength:uint = parseInt(media.fmtp['indexlength']);
      var indexDeltaLength:uint = parseInt(media.fmtp['indexdeltalength']);
      var CTSDeltaLength:uint = parseInt(media.fmtp['ctsdeltalength']);
      var DTSDeltaLength:uint = parseInt(media.fmtp['dtsdeltalength']);
      var RandomAccessIndication:uint = parseInt(media.fmtp['randomaccessindication']);
      var StreamStateIndication:uint = parseInt(media.fmtp['streamstateindication']);
      var AuxiliaryDataSizeLength:uint = parseInt(media.fmtp['auxiliarydatasizelength']);

      var data:ByteArray = pkt.getPayload();

      var configHeaderLength:uint =
        sizeLength + Math.max(indexLength, indexDeltaLength) + CTSDeltaLength + DTSDeltaLength +
        RandomAccessIndication + StreamStateIndication + AuxiliaryDataSizeLength;

      if (0 !== configHeaderLength) {
        /* The AU header section is not empty, read it from payload */
        var auHeadersLengthInBits:uint = data.readUnsignedShort(); // Always 2 octets, without padding
        var auHeadersLengthPadded:uint = (auHeadersLengthInBits + auHeadersLengthInBits % 8) / 8; // Add padding
        var auHeaders:ByteArray = new ByteArray();
        data.readBytes(auHeaders, 0, auHeadersLengthPadded);

        /* What should we do with the headers? */
      }

      dispatchEvent(new AACFrame(data, pkt.getTimestampMS()));
    }
  }
}
