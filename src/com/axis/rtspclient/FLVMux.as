package com.axis.rtspclient {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;
  import flash.net.NetStream;
  import flash.net.FileReference;

  import com.axis.rtspclient.RTP;

  public class FLVMux {
    private var container:ByteArray = new ByteArray();

    private var ns:NetStream;

    public function FLVMux()
    {
      ns = Player.getNetStream();

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
      container.writeShort(contents.length & 0x0000FFFF); // Length of string
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

      /* AVC Decoder Configuration Record */
      container.writeByte(0x01); // Version
      container.writeByte(0x64); // AVC Profile, High
      container.writeByte(0x00); // Profile compatibility
      container.writeByte(0x0D); // Level indication
      container.writeByte(0xFF); // 111111xx (xx=lengthSizeMinsOne)

      /* Sequence parameters, these should probably be more dynamic... */
      container.writeByte(0xE1); // 111xxxxx (xxxxx=numSequenceParameters)
      container.writeShort(0x0019); // Sequence Parameter Length
      container.writeUnsignedInt(0x6764000D);
      container.writeUnsignedInt(0xACD94141);
      container.writeUnsignedInt(0xFB011000);
      container.writeUnsignedInt(0x00030010);
      container.writeUnsignedInt(0x00000303);
      container.writeUnsignedInt(0xC8F14299);
      container.writeByte(0x60);

      /* Picture parameters these should probably be more dynamic... */
      container.writeByte(0x01); // Num picture parameters
      container.writeShort(0x0005); // Picture Parameter Length
      container.writeUnsignedInt(0x68EBECB2);
      container.writeByte(0x2C);


      var size:uint = container.position - start;

      /* Rewind and set the data size in tag header to actual size */
      var dataSize:uint = size - 11;
      container[sizePosition + 0] = dataSize & 0x00FF0000;
      container[sizePosition + 1] = dataSize & 0x0000FF00;
      container[sizePosition + 2] = dataSize & 0x000000FF;

      /* End of tag */
      container.writeUnsignedInt(size);
    }

    private function createVideoTag(nalu:NALU):void
    {
      var ts:uint = nalu.timestamp;
      var size:uint = 11; // Header to StreamID
      size += 1; // Video tag header
      size += 4; // AVC tag header
      size += nalu.bodySize;

      /* FLV Tag */
      container.writeUnsignedInt(0x09 << 24 | (size & 0x00FFFFFF)); // Type << 24 | size & 0x00FFFFFF
      container.writeUnsignedInt(ts >>> 24 | ts << 8);
      container.writeByte(0x00); container.writeByte(0x00); container.writeByte(0x00); // StreamID - always 0

      /* Video Tag Header */
      container.writeByte((nalu.isIDR ? 1 : 2) << 4 | 0x07); // Keyframe << 4 | CodecID
      container.writeUnsignedInt(0x01 << 24 | ts & 0x00FFFFFF); // AVC NALU << 24 | CompositionTime & 0x00FFFFFF

      /* Video Data */

      var n:ByteArray = nalu.getPayload();
/*    ExternalInterface.call(HTTPClient.jsEventCallbackName, "pre - Nalu ba", n.bytesAvailable);
      ExternalInterface.call(HTTPClient.jsEventCallbackName, "pre - container ba", container.bytesAvailable);
      ExternalInterface.call(HTTPClient.jsEventCallbackName, "pre - Nalu len", n.length);
      ExternalInterface.call(HTTPClient.jsEventCallbackName, "pre - container len", container.length);*/
      container.writeBytes(n, n.position);
      /*ExternalInterface.call(HTTPClient.jsEventCallbackName, "post - Nalu ba", n.bytesAvailable);
      ExternalInterface.call(HTTPClient.jsEventCallbackName, "post - container ba", container.bytesAvailable);
      ExternalInterface.call(HTTPClient.jsEventCallbackName, "post - Nalu len", n.length);
      ExternalInterface.call(HTTPClient.jsEventCallbackName, "post - container len", container.length);*/


      /* Previous Tag Size */
      container.writeUnsignedInt(size + 11);
    }


    public function onNALU(nalu:NALU):void
    {
      createVideoTag(nalu);

      container.position = 0;
      ExternalInterface.call(HTTPClient.jsEventCallbackName, "Appending bytes: ", container.bytesAvailable);
      ns.appendBytes(container);

      container.clear();
    }
  }
}
