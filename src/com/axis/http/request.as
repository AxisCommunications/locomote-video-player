package com.axis.http {
  import com.axis.rtspclient.ByteArrayUtils;
  import com.axis.Logger;

  import flash.utils.ByteArray;

  public class request {

    public static function readHeaders(dataInput:*, buffer:ByteArray):* {
      dataInput.readBytes(buffer, buffer.length);

      var index:int = ByteArrayUtils.indexOf(buffer, "\r\n\r\n", buffer.position);
      if (index === -1) {
        /* Not a full request yet */
        return false;
      }

      var dummy:ByteArray = new ByteArray();
      buffer.readBytes(dummy, 0, index + 4);

      var parsed:Object = parse(dummy.toString());
      if (parsed.headers['content-length'] &&
          int(parsed.headers['content-length']) > buffer.bytesAvailable) {
        /* Headers parsed fine, but full body is not here yet. */
        buffer.position = 0;
        return false;
      }

      return parsed;
    }

    public static function parse(data:String):Object {
      var ret:Object = {};

      var lines:Array = data.split('\r\n');
      var statusRegex:RegExp = /^(?P<proto>[^\/]+)\/(?P<version>[^ ]+) (?P<code>[0-9]+) (?P<message>.*)$/;
      var status:Array = statusRegex.exec(lines.shift());

      if (status) {
        /* statusRegex will fail if this is multipart block (in which case these parameters are not valid) */
        ret.proto = status.proto;
        ret.version = status.version;
        ret.code = uint(status.code);
        ret.message = status.message;
      }

      ret.headers = {};
      for each (var header:String in lines) {
        if (header.length === 0) continue;

        var t:Array = header.split(':');
        var key:String = t.shift().replace(/^[\s]*(.*)[\s]*$/, '$1').toLowerCase();
        var val:String = t.join(':').replace(/^[\s]*(.*)[\s]*$/, '$1');
        parseMiddleware(key, val, ret.headers);
      }

      return ret;
    }

    private static function parseMiddleware(key:String, val:String, hdr:Object):void {
      switch (key) {
        case 'www-authenticate':
          if (!hdr['www-authenticate'])
            hdr['www-authenticate'] = {};

          if (/^basic/i.test(val)) {
            var basicRealm:RegExp = /realm="([^"]*)"/i;
            hdr['www-authenticate'].basicRealm = basicRealm.exec(val)[1];
          }

          if (/^digest/i.test(val)) {
            var params:Array = val.substr(7).split(/,\s*/);
            for each (var p:String in params) {
              var kv:Array = p.split('=');
              if (2 !== kv.length) continue;

              if (kv[0].toLowerCase() === 'realm') kv[0] = 'digestRealm';
              hdr['www-authenticate'][kv[0]] = kv[1].replace(/^"(.*)"$/, '$1');
            }
          }

          break;
        default:
          /* In the default case, just take the value as-is */
          hdr[key] = val;
      }
    }
  }
}
