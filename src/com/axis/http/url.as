package com.axis.http {
  public class url {
    /**
     * Parses an URL.
     * mx.utils.URLUtil is not good enough since it doesn't support
     * authorization.
     *
     * @param url The URL represented as a string.
     * @return An object with the following parameters set:
     *         full, protocol, urlpath, user, pass, host, port.
     *         If URL part is not in the specified url, the corresponding
     *         value is null.
     */
    public static function parse(url:String):Object {
      var ret:Object = {};

      var regex:RegExp = /^(?P<protocol>[^:]+):\/\/(?P<login>[^\/]+)(?P<urlpath>.*)$/;
      var result:Array = regex.exec(url);

      ret.full = url;
      ret.protocol = result.protocol;
      ret.urlpath = result.urlpath;

      var parts:Array = result.urlpath.split('/');
      ret.basename = parts.pop().split(/\?|#/)[0];
      ret.basepath = parts.join('/');

      var loginSplit:Array = result['login'].split('@');
      var hostport:Array = loginSplit[0].split(':');
      var userpass:Array = [ null, null ];
      if (loginSplit.length === 2) {
        userpass = loginSplit[0].split(':');
        hostport = loginSplit[1].split(':');
      }

      ret.user = userpass[0];
      ret.pass = userpass[1];
      ret.host = hostport[0];

      ret.port = (null == hostport[1]) ? protocolDefaultPort(ret.protocol) : hostport[1];
      ret.portDefined = (null != hostport[1]);

      return ret;
    }

    public static function isAbsolute(url:String):Boolean {
      return /^[^:]+:\/\//.test(url);
    }

    private static function protocolDefaultPort(protocol:String):uint {
      switch (protocol) {
        case 'rtmp': return 1935;
        case 'rtsp': return 554;
        case 'rtsph': return 80;
        case 'rtsphs': return 443;
        case 'rtsphap': return 443;
        case 'http': return 80;
        case 'https': return 443;
        case 'httpm': return 80;
      }

      return 0;
    }
  }
}
