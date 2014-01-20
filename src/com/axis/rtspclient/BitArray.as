package com.axis.rtspclient {

  import flash.utils.ByteArray;

  public class BitArray extends ByteArray
  {
    private var src:ByteArray;
    private var byte:uint;
    private var bitpos:uint;

    public function BitArray(src:ByteArray)
    {
      this.src    = src;
      this.bitpos = 0;
      this.byte   = 0; /* This should really be undefied, uint wont allow it though */
    }

    public function readBits(length:uint):uint
    {
      if (32 < length || 0 === length) {
       /* To big for an uint */
       throw new Error("Bit ranges must be 1 - 32.");
      }

      var result:uint = 0;
      for (var i:uint = 1; i <= length; ++i) {
        if (0 === bitpos) {
          /* Previous byte all read out. Get a new one. */
          byte = src.readUnsignedByte();
        }

        /* Shift result one left to make room for another bit,
           then add the next bit on the stream. */
        result = (result << 1) | ((byte >> (8 - (++bitpos))) & 0x01);
        bitpos %= 8;
      }

      return result;
    }

    public function readUnsignedExpGolomb():uint
    {
      var bitsToRead:uint = 0;
      while (readBits(1) !== 1) bitsToRead++;

      if (bitsToRead == 0) return 0; /* Easy peasy, just a single 1. This is 0 in exp golomb */
      if (bitsToRead >= 31) throw new Error("exp-golomb larger than 32 bits is unsupported.")

      var n:uint = readBits(bitsToRead); /* Read all bits part of this number */
      n |= (0x1 << (bitsToRead)); /* Move in the 1 read by while above */

      return n - 1; /* Because result in exp golomb is one larger */
    }
  }
}
