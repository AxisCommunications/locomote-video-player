package com.axis.rtspclient {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;
  import flash.net.NetStream;
  import flash.net.FileReference;
  import mx.utils.Base64Decoder;

  import com.axis.rtspclient.RTP;
  import com.axis.rtspclient.ByteArrayUtils;

  public class FLVMux {

    private var sdp:SDP;
    private var container:ByteArray = new ByteArray();
    private var loggedBytes:ByteArray = new ByteArray();
    private var initialTimestamp:int = -1;

    public function FLVMux(sdp:SDP)
    {
      container.writeByte(0x46); // 'F'
      container.writeByte(0x4C); // 'L'
      container.writeByte(0x56); // 'V'
      container.writeByte(0x01); // Version 1
      container.writeByte(0x00 << 2 | 0x01); // Audio << 2 | Video
      container.writeUnsignedInt(0x09) // Reserved: usually is 0x09
      container.writeUnsignedInt(0x0) // Previous tag size: shall be 0

      this.sdp = sdp;

      createMetaDataTag();

      /* Initial parameters must be taken from SDP file. Additional may be received as NAL */
      var sets:Array = sdp.getMediaBlock('video').fmtp['sprop-parameter-sets'].split(',');
      var sps:Base64Decoder = new Base64Decoder();
      var pps:Base64Decoder = new Base64Decoder();
      sps.decode(sets[0]);
      pps.decode(sets[1]);
      createDecoderConfigRecordTag(sps.toByteArray(), pps.toByteArray());
    }

    private function writeECMAArray(contents:Object):uint
    {
      var size:uint = 0;
      var count:uint = 0;

      for (var s:String in contents) count++;

      container.writeByte(0x08); // ECMA Array Type
      container.writeUnsignedInt(count); // (Approximate) number of elements in ECMA array
      size += 1 + 4;

      for (var key:String in contents) {
        container.writeShort(key.length); // Length of key
        container.writeUTFBytes(key); // The key itself
        size += 2 + key.length;
        switch(contents[key]) {
        case contents[key] as Number:
          size += writeDouble(contents[key]);
          break;

        case contents[key] as String:
          size += writeString(contents[key]);
          break;

        default:
          ExternalInterface.call(HTTPClient.jsEventCallbackName,
            "Unknown type in ECMA array: " + typeof contents[key]);

          break;
        }
      }

      /* ECMA Array End */
      container.writeByte(0x00);
      container.writeByte(0x00);
      container.writeByte(0x09);
      size += 3;

      return size;
    }

    private function writeDouble(contents:Number):uint
    {
      container.writeByte(0x00); // Number type marker
      container.writeDouble(contents);
      return 1 + 8;
    }

    private function writeString(contents:String):uint
    {
      container.writeByte(0x02); // String type marker
      container.writeShort(contents.length); // Length of string
      container.writeUTFBytes(contents); // String
      return 1 + 2 + contents.length;
    }

    private function parseSPS(sps:BitArray):Object
    {
      var nalhdr:uint      = sps.readBits(8);
      var profile:uint     = sps.readBits(8);
      var constraints:uint = sps.readBits(8);
      var level:uint       = sps.readBits(8);

      var seq_parameter_set_id:uint = sps.readUnsignedExpGolomb();
      if (-1 !== [100, 110, 122, 244, 44, 83, 86, 118, 128, 138].indexOf(profile)) {
        /* Parse chroma/luma parameters */
        throw new Error("No support for parsing Chroma/Luma parameters");
      }

      var log2_max_frame_num_minus4:uint = sps.readUnsignedExpGolomb();
      var pic_order_cnt_type:uint        = sps.readUnsignedExpGolomb();
      if (0 == pic_order_cnt_type) {
        var log2_max_pic_order_cnt_lsb_minus4:uint = sps.readUnsignedExpGolomb();
      } else if (1 == pic_order_cnt_type) {
        throw new Error("No support for parsing 'pic_order_cnt_type' != 0");
      }

      var max_num_ref_frames:uint                   = sps.readUnsignedExpGolomb();
      var gaps_in_frame_num_value_allowed_flag:uint = sps.readBits(1);
      var pic_width_in_mbs_minus1:uint              = sps.readUnsignedExpGolomb();
      var pic_height_in_map_units_minus1:uint       = sps.readUnsignedExpGolomb();
      var pic_frame_mbs_only_flag:uint              = sps.readBits(1);

      /* There's more information here, but can't be bothered right now */

      return {
        'profile' : profile,
        'level'   : level / 10.0,
        'width'   : (pic_width_in_mbs_minus1 + 1) * 16,
        'height'  : (2 - pic_frame_mbs_only_flag) * (pic_height_in_map_units_minus1 + 1) * 16
      };
    }

    public function createMetaDataTag():void
    {
      var size:uint = 0;

      /* FLV Tag */
      var sizePosition:uint = container.position + 1; // 'Size' is the 24 last byte of the next uint
      container.writeUnsignedInt(0x00000012 << 24 | (size & 0x00FFFFFF)); // Type << 24 | size & 0x00FFFFFF
      container.writeUnsignedInt(0x00000000); // Timestamp & TimestampExtended
      container.writeByte(0x00); // StreamID - always 0
      container.writeByte(0x00); // StreamID - always 0
      container.writeByte(0x00); // StreamID - always 0
      size += 4 + 4 + 3;

      /* Method call */
      size += writeString("onMetaData");

      /* Decode the base64 encoded parameter sets to pass to parseSPS */
      var sets:Array = sdp.getMediaBlock('video').fmtp['sprop-parameter-sets'].split(',');
      var spsdec:Base64Decoder = new Base64Decoder();
      spsdec.decode(sets[0]);
      var sps:BitArray = new BitArray(spsdec.toByteArray());
      var params:Object = parseSPS(sps);

      /* Arguments */
      size += writeECMAArray({
        videocodecid    : 7.0, /* Only support AVC (H.264) */
        width           : params.width,
        height          : params.height,
        avcprofile      : params.profile,
        avclevel        : params.level,
        metadatacreator : "Slush FLV Muxer",
        creationdate    : new Date().toString()
      });

      container.writeUnsignedInt(size); // Previous tag size

      /* Rewind and set the data size in tag header to actual size */
      var dataSize:uint = size - 11;
      container[sizePosition + 0] = dataSize & 0x00FF0000;
      container[sizePosition + 1] = dataSize & 0x0000FF00;
      container[sizePosition + 2] = dataSize & 0x000000FF;
    }

    public function createDecoderConfigRecordTag(sps:ByteArray, pps:ByteArray):void
    {
      var start:uint = container.position;

      /* FLV Tag */
      var sizePosition:uint = container.position + 1; // 'Size' is the 24 last byte of the next uint
      container.writeUnsignedInt(0x00000009 << 24 | (0x000000 & 0x00FFFFFF)); // Type << 24 | size & 0x00FFFFFF
      container.writeUnsignedInt(0x00000000); // Timestamp & TimestampExtended
      container.writeByte(0x00); // StreamID - always 0
      container.writeByte(0x00); // StreamID - always 0
      container.writeByte(0x00); // StreamID - always 0

      /* Video Tag Header */
      container.writeByte(0x01 << 4 | 0x07); // Keyframe << 4 | CodecID
      container.writeUnsignedInt(0x00 << 24 | 0x00000000); // AVC NALU << 24 | CompositionTime

      writeDecoderConfigurationRecord();
      writeParameterSets(sps, pps);

      var size:uint = container.position - start;

      /* Rewind and set the data size in tag header to actual size */
      var dataSize:uint = size - 11;
      container[sizePosition + 0] = dataSize & 0x00FF0000;
      container[sizePosition + 1] = dataSize & 0x0000FF00;
      container[sizePosition + 2] = dataSize & 0x000000FF;

      /* End of tag */
      container.writeUnsignedInt(size);
    }

    public function writeDecoderConfigurationRecord():void
    {
      /* Always take this from SDP file. Is this correct? */
      var profilelevelid:uint = parseInt(sdp.getMediaBlock('video').fmtp['profile-level-id'], 16);
      container.writeByte(0x01); // Version
      container.writeByte((profilelevelid & 0x00FF0000) >> 16); // AVC Profile, Baseline
      container.writeByte((profilelevelid & 0x0000FF00) >> 8); // Profile compatibility
      container.writeByte((profilelevelid & 0x000000FF) >> 0); // Level indication
      container.writeByte(0xFF); // 111111xx (xx=lengthSizeMinusOne)
    }

    public function writeParameterSets(sps:ByteArray, pps:ByteArray):void
    {
      if (sps.bytesAvailable > 0) {
        /* There is one sps available */
        container.writeByte(0xE1); // 111xxxxx (xxxxx=numSequenceParameters), only support 1
        container.writeShort(sps.bytesAvailable); // Sequence parameter set 1 length
        container.writeBytes(sps, sps.position); // Actual parameters
      } else {
        /* No sps here */
        container.writeByte(0xE0); // 111xxxxx (xxxxx=numOfSequenceParameters), 0 sps here
      }

      if (pps.bytesAvailable > 0) {
        container.writeByte(0x01); // Num picture parameters, only support 1
        container.writeShort(pps.bytesAvailable); // Picture parameter length
        container.writeBytes(pps, pps.position); // Actual parameters
      } else {
        /* No pps here */
        container.writeByte(0x00); // numOfPictureParameterSets
      }
    }

    private function createVideoTag(nalu:NALU):void
    {
      var ts:uint = nalu.timestamp;

      if (initialTimestamp == -1) {
        initialTimestamp = ts;
      }

      ts -= initialTimestamp;

      var size:uint = 0; // Header to StreamID
      size += 1; // Video tag header
      size += 4; // AVC tag header
      size += nalu.writeSize(); // NALU size contribution

      /* FLV Tag */
      container.writeUnsignedInt(0x09 << 24 | (size & 0x00FFFFFF)); // Type << 24 | size & 0x00FFFFFF
      container.writeUnsignedInt(((ts >>> 24) & 0xFF) | ((ts << 8) & 0xFFFFFF00));
      container.writeByte(0x00);
      container.writeByte(0x00);
      container.writeByte(0x00);

      /* Video Tag Header */
      container.writeByte((nalu.isIDR() ? 1 : 2) << 4 | 0x07); // Keyframe << 4 | CodecID
      container.writeUnsignedInt(0x01 << 24 | (0x0 & 0x00FFFFFF)); // AVC NALU << 24 | CompositionTime & 0x00FFFFFF

      /* Video Data */
      nalu.writeStream(container);

      /* Previous Tag Size */
      container.writeUnsignedInt(size + 11);
    }

    public function onNALU(nalu:NALU):void
    {
      switch (nalu.ntype) {
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
        /* 1 - 5 are Video Coding Layer (VCL) unit type class (Rec. ITU-T H264 04/2013), and contains video data */
        createVideoTag(nalu);
        break;

      case 7:
        /* What to do about these? Inserting new decoder configurations doesn't seem to work. */
        /* createDecoderConfigRecordTag(nalu.getPayload(), new ByteArray()); */
        break;

      case 8:
        /* What to do about these? Inserting new decoder configurations doesn't seem to work. */
        /* createDecoderConfigRecordTag(new ByteArray(), nalu.getPayload()); */
        break;

      default:
        ExternalInterface.call(HTTPClient.jsEventCallbackName, "Unsupported NALU type: " + nalu.ntype);
        /* Return here as nothing was created, and thus nothing should be appended */
        return;
      }

      var ns:NetStream = Player.getNetStream();
      container.position = 0;
      ns.appendBytes(container);
      container.clear();

      /*
      ExternalInterface.call(HTTPClient.jsEventCallbackName,
        "Video buffer: " + ns.info.videoBufferByteLength + " bytes, " +
        ns.info.videoBufferLength + " seconds, " +
        ns.info.droppedFrames + " frames dropped, " +
        'FPS: ' + ns.currentFPS + ' frames/second.');
      */
    }
  }
}
