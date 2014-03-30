package com.axis.http {

  import flash.utils.ByteArray;
  import flash.net.Socket;

  import com.axis.rtspclient.ByteArrayUtils;

  public class request {

    public static function readHeaders(socket:Socket, buffer:ByteArray):* {
      socket.readBytes(buffer);

      var index:int = ByteArrayUtils.indexOf(buffer, "\r\n\r\n");
      if (index === -1) {
        /* Not a full request yet */
        return false;
      }

      var dummy:ByteArray = new ByteArray();
      buffer.readBytes(dummy, 0, index + 4);

      return parse(dummy.toString());
    }

    public static function parse(data:String):Object
    {
      var ret:Object = {};

      var lines:Array = data.split('\r\n');

      var statusRegex:RegExp = /^HTTP\/(?P<version>[^ ]+) (?P<code>[0-9]+) (?P<message>.*)$/;
      var status:Array = statusRegex.exec(lines.shift());

      ret.version = status.version;
      ret.code = uint(status.code);
      ret.messsage = status.message;

      ret.headers = {};
      for each (var header:String in lines) {
        if (header.length === 0) continue;

        var t:Array = header.split(':');
        var key:String = t[0].replace(/^[\s]*(.*)[\s]*$/, '$1').toLowerCase();
        var val:String = t[1].replace(/^[\s]*(.*)[\s]*$/, '$1');
        parseMiddleware(key, val, ret.headers);
      }

      return ret;
    }

    private static function parseMiddleware(key:String, val:String, hdr:Object):void
    {
      switch (key) {
        case 'www-authenticate':
          if (!hdr['www-authenticate'])
            hdr['www-authenticate'] = {};

          if (/basic realm/i.test(val)) {
            var basicRealm:RegExp = /basic realm=\"([^\"]+)\"/i;
            hdr['www-authenticate'].basicRealm = basicRealm.exec(val)[1];
          }

          if (/digest realm/i.test(val)) {
            var digestRealm:RegExp = /digest realm=\"([^\"]+)\"/i;
            var nonce:RegExp = /nonce=\"([^\"]+)\"/i;
            var qop:RegExp = /qop=\"([^\"]+)\"/i;
            hdr['www-authenticate'].digestRealm = digestRealm.exec(val)[1];
            hdr['www-authenticate'].nonce = nonce.exec(val)[1];
            hdr['www-authenticate'].qop = qop.exec(val)[1];
          }

          break;
        default:
          /* In the default case, just take the value as-is */
          hdr[key] = val;
      }
    }
  }
}
