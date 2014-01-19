package com.axis.rtspclient {

  import flash.events.Event;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;
  import com.axis.rtspclient.ByteArrayUtils;

  public class RTP extends Event
  {
    public static const NEW_PACKET:String = "NEW_PACKET";

    private var data:ByteArray;
    private var media:Object;

    public var version:uint;
    public var padding:uint;
    public var extension:uint;
    public var csrc:uint;
    public var ssrc:uint;
    public var marker:uint;
    public var pt:uint;
    public var sequence:uint;
    public var timestamp:uint;

    public var headerLength:uint;
    public var bodyLength:uint;

    public function RTP(pkt:ByteArray, sdp:SDP)
    {
      super(RTP.NEW_PACKET, false, false);

      var line1:uint = pkt.readUnsignedInt();

      version   = (line1 & 0xC0000000) >>> 30;
      padding   = (line1 & 0x20000000) >>> 29;
      extension = (line1 & 0x10000000) >>> 28;
      csrc      = (line1 & 0x0F000000) >>> 24;
      marker    = (line1 & 0x00800000) >>> 23;
      pt        = (line1 & 0x007F0000) >>> 16;
      sequence  = (line1 & 0x0000FFFF) >>> 0;
      timestamp = pkt.readUnsignedInt();
      ssrc      = pkt.readUnsignedInt();

      headerLength = pkt.position;
      bodyLength   = pkt.bytesAvailable;

      media = sdp.getMediaBlock('video');
      if (null === media || -1 === media.fmt.indexOf(pt)) {
        ExternalInterface.call('console.log', 'Media description for payload type: ' + pt + ' not provided.');
      }


      this.data = pkt;
    }

    public function getPayload():ByteArray
    {
      return data;
    }

    public function getTimestampMS():uint
    {
      return 1000 * (timestamp / media.rtpmap[pt].clock);
    }
  }
}
