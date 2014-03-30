package com.axis.http {

  import mx.utils.ObjectUtil;
  public class url {

    public static function parse(url:String):Object
    {
      var ret:Object = {};

      var regex:RegExp = /^(?P<protocol>[^:]+):\/\/(?P<login>[^\/]+)(?P<urlpath>.*)$/;
      var result:Array = regex.exec(url);

      ret.protocol = result.protocol;
      ret.urlpath = result.urlpath;

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

      return ret;
    }

    public static function isAbsolute(url:String):Boolean
    {
      return /^[^:]+:\/\//.test(url);
    }

    private static function protocolDefaultPort(protocol:String):uint
    {
      switch (protocol) {
        case 'rtsp': return 554;
        case 'http': return 80;
        case 'https': return 443;
      }

      return 0;
    }
  }
}
