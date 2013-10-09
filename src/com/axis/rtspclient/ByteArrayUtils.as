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

  }

}
