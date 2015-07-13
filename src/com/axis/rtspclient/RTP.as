package com.axis.rtspclient {
  import com.axis.Logger;
  import com.axis.rtspclient.ByteArrayUtils;

  import flash.events.Event;
  import flash.utils.ByteArray;

  public class RTP extends Event {
    private var data:ByteArray;
    private var media:Object;
    private var timing:RTPTiming;

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

    public function RTP(pkt:ByteArray, sdp:SDP, timing:RTPTiming) {
      this.timing = timing;
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

      media = sdp.getMediaBlockByPayloadType(pt);
      if (null === media || -1 === media.fmt.indexOf(pt)) {
        Logger.log('Media description for payload type: ' + pt + ' not provided.');
      }

      super(media.type.toUpperCase() + '_' + media.rtpmap[pt].name.toUpperCase() + '_PACKET', false, false);

      this.data = pkt;
    }

    public function getPayload():ByteArray {
      return data;
    }

    public function getTimestampMS():uint {
      return timing.range.from + (1000 * (timestamp - timing.rtpTimeForControl(media.control)) / media.rtpmap[pt].clock);
    }

    public override function toString():String {
      return "RTP(" +
        "version:"   + version   + ", " +
        "padding:"   + padding   + ", " +
        "extension:" + extension + ", " +
        "csrc:"      + csrc      + ", " +
        "marker:"    + marker    + ", " +
        "pt:"        + pt        + ", " +
        "sequence:"  + sequence  + ", " +
        "timestamp:" + timestamp + ", " +
        "ssrc:"      + ssrc      + ")";
    }
  }
}
