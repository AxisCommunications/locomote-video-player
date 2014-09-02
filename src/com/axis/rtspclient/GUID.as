package com.axis.rtspclient {
  public class GUID {
    public static function create():String {
      var uid:Array      = new Array();
      var chars:Array    = new Array(48, 49, 50, 51, 52, 53, 54, 55,
                                     56, 57, 65, 66, 67, 68, 69, 70);
      var separator:uint = 45;
      var template:Array = new Array(8, 4, 4, 4, 12);

      for (var a:uint = 0; a < template.length; a++) {
        for (var b:uint = 0; b < template[a]; b++) {
          uid.push(chars[Math.floor(Math.random() * chars.length)]);
        } if (a < template.length - 1) {
          uid.push(separator);
        }
      }

      return String.fromCharCode.apply(null, uid);
    }
  }
}
