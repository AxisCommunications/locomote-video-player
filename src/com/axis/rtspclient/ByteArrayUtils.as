package com.axis.rtspclient {

  import flash.utils.ByteArray;

  public class ByteArrayUtils {

    public static function indexOf(target:ByteArray, pattern:*, fromIndex:int = 0):int {
      var arr:Array, end:Boolean, found:Boolean, a:int, i:int, j:int, k:int;
      var toFind:ByteArray = toByteArray(pattern);
      if (toFind == null) {
        // ** type of pattern unsupported **
        throw new Error("Unsupported Pattern");
        return;
      }

      a = toFind.length;
      j = target.length - a;

      if (fromIndex < 0) {
        i = j + fromIndex;
        if (i < 0) {
          return -1;
        }
      } else {
        i = fromIndex;
      }

      while (!end) {
        if (target[i] == toFind[0]) {
          // ** found a possible candidate **
          found = true;
          k = a;
          while (--k) {
            if (target[i + k] != toFind[k]) {
              // ** doesn't match, false candidate **
              found = false;
              break;
            }
          }
          if (found) {
            return i;
          }
        }
        if (fromIndex < 0) {
          end = (--i < 0);
        } else {
          end = (++i > j);
        }
      }
      return -1;
    }

    public static function toByteArray(obj:*):ByteArray {
      var toFind:ByteArray;
      if (obj is ByteArray) {
        toFind = obj;
      } else {
        toFind  = new ByteArray();
        if (obj is Array) {
          // ** looking for a sequence of target **
          var i:int = obj.length;
          while (i--) {
            toFind[i] = obj[i];
          }
        } else if (obj is String) {
          // ** looking for a sequence of string characters **
          toFind.writeUTFBytes(obj);
        } else {
          return null;
        }
      }
      return toFind;
    }

    public static function hexdump(ba:ByteArray, offset:uint = 0, length:int = -1):String
    {
      var result:String = "";

      var realOffset:uint = offset;

      var realLength:int = (length === -1) ?
        ba.length - realOffset :
        Math.min(ba.length - realOffset, length);

      for (var i:int = realOffset; i < realOffset + realLength; i++) {
        result += "" + (ba[i] < 16 ? "0" : "") + ba[i].toString(16) + (((i - realOffset) % 16 == 7) ? " " : "") + (((i - realOffset) % 16 == 15) ? "\n" : " ");
      }
      return result;
    }

    public static function appendByteArray(dest:ByteArray, src:ByteArray):void
    {
      var prepos:uint = dest.position;
      dest.position   = dest.length;
      dest.writeBytes(src, src.position);
      dest.position   = prepos;
    }

    public static function createFromHexstring(hex:String):ByteArray
    {
      var res:ByteArray = new ByteArray();
      for (var i:uint = 0; i < hex.length; i += 2) {
        res.writeByte(parseInt(hex.substr(i, 2), 16));
      }

      return res;
    }
  }
}
