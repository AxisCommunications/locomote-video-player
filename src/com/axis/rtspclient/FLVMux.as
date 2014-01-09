package com.axis.rtspclient {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;
  import flash.net.NetStream;
  import flash.net.FileReference;

  import com.axis.rtspclient.RTP;
  import com.axis.rtspclient.ByteArrayUtils;

  public class FLVMux {

    private var container:ByteArray = new ByteArray();
    private var loggedBytes:ByteArray = new ByteArray();
    private var initialTimestamp:int = -1;

    public function FLVMux()
    {
      container.writeByte(0x46); // 'F'
      container.writeByte(0x4C); // 'L'
      container.writeByte(0x56); // 'V'
      container.writeByte(0x01); // Version 1
      container.writeByte(0x00 << 2 | 0x01); // Audio << 2 | Video
      container.writeUnsignedInt(0x09) // Reserved: usually is 0x09
      container.writeUnsignedInt(0x0) // Previous tag size: shall be 0

      createMetaDataTag();
      createDecoderConfigRecordTag();
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
        switch(typeof contents[key]) {
        case 'number':
          size += writeDouble(contents[key]);
          break;

        case 'string':
          size += writeString(contents[key]);
          break;

        default:
          ExternalInterface.call(HTTPClient.jsEventCallbackName,
            "Unknown type in ECMA array: ", typeof contents[key]);
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

      /* Arguments */
      size += writeECMAArray({
        videocodecid    : 7.0,
        width           : 1024.0,
        height          : 768.0,
        framerate       : 17.0,
        metadatacreator : "Slush FLV Muxer",
        creationdate    : new Date().toString()
      });

      container.writeUnsignedInt(size); // Previous tag size

      /* Rewind and set the data size in tag header to actual size */
      var dataSize:uint = size - 11;
      container[sizePosition + 0] = dataSize & 0x00FF0000;
      container[sizePosition + 1] = dataSize & 0x0000FF00;
      container[sizePosition + 2] = dataSize & 0x000000FF;

      //ExternalInterface.call(HTTPClient.jsEventCallbackName, ByteArrayUtils.hexdump(container, 13));
      ExternalInterface.call(HTTPClient.jsEventCallbackName, 'metadata size: ' + dataSize);
    }

    public function createDecoderConfigRecordTag():void
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

      /* AVC Decoder Configuration Record TODO: parse from SDP file */
      container.writeByte(0x01); // Version
      container.writeByte(0x42); // AVC Profile, Baseline
      container.writeByte(0x00); // Profile compatibility
      container.writeByte(0x29); // Level indication
      container.writeByte(0xFF); // 111111xx (xx=lengthSizeMinsOne)

      /* Sequence parameters, these should probably be more dynamic... */
      container.writeByte(0xE1); // 111xxxxx (xxxxx=numSequenceParameters)
      container.writeShort(0x0013); // Sequence Parameter Set 1 Length
      container.writeUnsignedInt(0x67420029);
      container.writeUnsignedInt(0xe2900800);
      container.writeUnsignedInt(0xc3602dc0);
      container.writeUnsignedInt(0x40406907);
      container.writeShort(0x8911);
      container.writeByte(0x50);


      /* Picture parameters these should probably be more dynamic... */
      container.writeByte(0x01); // Num picture parameters
      container.writeShort(0x0004); // Picture Parameter Length
      container.writeUnsignedInt(0x68CE3C80);

      var size:uint = container.position - start;

      /* Rewind and set the data size in tag header to actual size */
      var dataSize:uint = size - 11;
      container[sizePosition + 0] = dataSize & 0x00FF0000;
      container[sizePosition + 1] = dataSize & 0x0000FF00;
      container[sizePosition + 2] = dataSize & 0x000000FF;

      /* End of tag */
      container.writeUnsignedInt(size);

      //ExternalInterface.call(HTTPClient.jsEventCallbackName, 'config:');
      //ExternalInterface.call(HTTPClient.jsEventCallbackName,
      //    ByteArrayUtils.hexdump(container, start));
    }

    private function createVideoTag(nalu:NALU):void
    {
      var ts:uint = nalu.timestamp;

      if (initialTimestamp == -1) {
        initialTimestamp = ts;
      }

      ts -= initialTimestamp;
      //ExternalInterface.call(HTTPClient.jsEventCallbackName, "timestamp: ", ts);

      var size:uint = 0; // Header to StreamID
      size += 1; // Video tag header
      size += 4; // AVC tag header
      size += nalu.bodySize;
      size += 5;  // NALU header

      /* FLV Tag */
      container.writeUnsignedInt(0x09 << 24 | (size & 0x00FFFFFF)); // Type << 24 | size & 0x00FFFFFF
      container.writeUnsignedInt(((ts >>> 24) & 0xFF) | ((ts << 8) & 0xFFFFFF00));
      container.writeByte(0x00);
      container.writeByte(0x00);
      container.writeByte(0x00);

      /* Video Tag Header */
      container.writeByte((nalu.isIDR ? 1 : 2) << 4 | 0x07); // Keyframe << 4 | CodecID
      container.writeUnsignedInt(0x01 << 24 | (0x0 & 0x00FFFFFF)); // AVC NALU << 24 | CompositionTime & 0x00FFFFFF


      //container.writeUnsignedInt(0x000062f9);
      //container.writeByte(0x65);

      /* Video Data */
      var n:ByteArray = nalu.getPayload();
      container.writeShort(0x0000); // DON
      container.writeShort(nalu.bodySize + 1); // NALU length
      container.writeByte(nalu.isIDR ? 0x65 : 0x41); // NAL header
      container.writeBytes(n, n.position);

      /* Previous Tag Size */
      container.writeUnsignedInt(size + 11);
    }

    private var hasLogged:Boolean = false;
    private var hasSkippedFirst:Boolean = false;
    public function onNALU(nalu:NALU):void
    {
      //ExternalInterface.call(HTTPClient.jsEventCallbackName, "onNALU");
      if (nalu.getPayload().bytesAvailable >= 200) {
        //ExternalInterface.call(HTTPClient.jsEventCallbackName, "Creating video tag");
        createVideoTag(nalu);
      } else {
        //ExternalInterface.call(HTTPClient.jsEventCallbackName, "Not creating video tag");
      }

      var ns:NetStream = Player.getNetStream();

      container.position = 0;

      if (container.bytesAvailable > 0) {
        //ExternalInterface.call(HTTPClient.jsEventCallbackName, "Appending bytes: ", container.bytesAvailable);
        /*if (hasSkippedFirst) {
          container.readBytes(loggedBytes, loggedBytes.length);
        }
        hasSkippedFirst = true;

        container.position = 0;*/
        ns.appendBytes(container);
        //ExternalInterface.call(HTTPClient.jsEventCallbackName, ByteArrayUtils.hexdump(container));
        ExternalInterface.call(HTTPClient.jsEventCallbackName, "Video buffer: " + ns.info.videoBufferByteLength + " bytes, " + ns.info.videoBufferLength + " s." );
      }

      /*if (loggedBytes.length > 200000 && !hasLogged) {
        hasLogged = true;
        ExternalInterface.call(HTTPClient.jsEventCallbackName, ByteArrayUtils.hexdump(loggedBytes));
      }*/

      container.clear();
    }
  }
}
