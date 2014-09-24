package com.axis.rtspclient {
  import com.axis.ErrorManager;
  import com.axis.Logger;

  import flash.utils.ByteArray;

  import mx.utils.StringUtil;

  public class SDP {
    private var version:int = -1;
    private var origin:Object;
    private var sessionName:String;
    private var timing:Object;
    private var sessionBlock:Object = new Object();
    private var media:Object = new Object();

    public function SDP() {
    }

    public function parse(content:ByteArray):Boolean {
      var dataString:String = content.toString();
      var success:Boolean = true;
      var currentMediaBlock:Object = sessionBlock;

      for each (var line:String in content.toString().split("\n")) {
        line = line.replace(/\r/, ''); /* Delimiter '\r\n' is allowed, if this is the case, remove '\r' too */
        if (0 === line.length) {
          /* Empty row (last row perhaps?), skip to next */
          continue;
        }

        switch (line.charAt(0)) {
        case 'v':
          if (-1 !== version) {
            Logger.log('Version present multiple times in SDP');
            return false;
          }
          success &&= parseVersion(line);
          break;

        case 'o':
          if (null !== origin) {
            Logger.log('Origin present multiple times in SDP');
            return false;
          }
          success &&= parseOrigin(line);
          break;

        case 's':
          if (null !== sessionName) {
            Logger.log('Session Name present multiple times in SDP');
            return false;
          }
          success &&= parseSessionName(line);
          break;

        case 't':
          if (null !== timing) {
            Logger.log('Timing present multiple times in SDP');
            return false;
          }
          success &&= parseTiming(line);
          break;

        case 'm':
          if (null !== currentMediaBlock && sessionBlock !== currentMediaBlock) {
            /* Complete previous block and store it */
            media[currentMediaBlock.type] = currentMediaBlock;
          }

          /* A wild media block appears */
          currentMediaBlock = new Object();
          currentMediaBlock.rtpmap = new Object();
          parseMediaDescription(line, currentMediaBlock);
          break;

        case 'a':
          parseAttribute(line, currentMediaBlock);
          break;

        default:
          Logger.log('Ignored unknown SDP directive: ' + line);
          break;
        }
      }

      media[currentMediaBlock.type] = currentMediaBlock;

      return success;
    }

    private function parseVersion(line:String):Boolean {
      var matches:Array = line.match(/^v=([0-9]+)$/);
      if (0 === matches.length) {
        Logger.log('\'v=\' (Version) formatted incorrectly: ' + line);
        return false;
      }

      version = matches[1];
      if (0 !== version) {
        Logger.log('Unsupported SDP version:' + version);
        return false;
      }

      return true;
    }

    private function parseOrigin(line:String):Boolean {
      var matches:Array = line.match(/^o=([^ ]+) ([0-9]+) ([0-9]+) (IN) (IP4|IP6) ([^ ]+)$/);
      if (0 === matches.length) {
        Logger.log('\'o=\' (Origin) formatted incorrectly: ' + line);
        return false;
      }

      this.origin = new Object();
      this.origin.username       = matches[1];
      this.origin.sessionid      = matches[2];
      this.origin.sessionversion = matches[3];
      this.origin.nettype        = matches[4];
      this.origin.addresstype    = matches[5];
      this.origin.unicastaddress = matches[6];

      return true;
    }

    private function parseSessionName(line:String):Boolean {
      var matches:Array = line.match(/^s=([^\r\n]+)$/);
      if (0 === matches.length) {
        Logger.log('\'s=\' (Session Name) formatted incorrectly: ' + line);
        return false;
      }

      this.sessionName = matches[1];

      return true;
    }

    private function parseTiming(line:String):Boolean {
      var matches:Array = line.match(/^t=([0-9]+) ([0-9]+)$/);
      if (0 === matches.length) {
        Logger.log('\'t=\' (Timing) formatted incorrectly: ' + line);
        return false;
      }

      this.timing = new Object();
      timing.start = matches[1];
      timing.stop  = matches[2];

      return true;
    }

    private function parseMediaDescription(line:String, media:Object):Boolean {
      var matches:Array = line.match(/^m=([^ ]+) ([^ ]+) ([^ ]+)[ ]/);
      if (0 === matches.length) {
        Logger.log('\'m=\' (Media) formatted incorrectly: ' + line);
        return false;
      }

      media.type  = matches[1];
      media.port  = matches[2];
      media.proto = matches[3];
      media.fmt   = line.substr(matches[0].length).split(' ').map(function(fmt:*, index:int, array:Array):int {
        return parseInt(fmt);
      });

      return true;
    }

    private function parseAttribute(line:String, media:Object):Boolean {
      if (null === media) {
        /* Not in a media block, can't be bothered parsing attributes for session */
        return true;
      }

      var matches:Array; /* Used for some cases of below switch-case */
      var separator:int    = line.indexOf(':');
      var attribute:String = line.substr(0, (-1 === separator) ? 0x7FFFFFFF : separator); /* 0x7FF.. is default */

      switch (attribute) {
      case 'a=recvonly':
      case 'a=sendrecv':
      case 'a=sendonly':
      case 'a=inactive':
        media.mode = line.substr('a='.length);
        break;

      case 'a=control':
        media.control = line.substr('a=control:'.length);
        break;

      case 'a=rtpmap':
        matches = line.match(/^a=rtpmap:(\d+) (.*)$/);
        if (null === matches) {
          Logger.log('Could not parse \'rtpmap\' of \'a=\'');
          return false;
        }

        var payload:int = parseInt(matches[1]);
        media.rtpmap[payload] = new Object();

        var attrs:Array = matches[2].split('/');
        media.rtpmap[payload].name  = attrs[0];
        media.rtpmap[payload].clock = attrs[1];
        if (undefined !== attrs[2]) {
          media.rtpmap[payload].encparams = attrs[2];
        }

        break;

      case 'a=fmtp':
        matches = line.match(/^a=fmtp:(\d+) (.*)$/);
        if (0 === matches.length) {
          Logger.log('Could not parse \'fmtp\'  of \'a=\'');
          return false;
        }

        media.fmtp = new Object();
        for each (var param:String in matches[2].split(';')) {
          var idx:int = param.indexOf('=');
          media.fmtp[StringUtil.trim(param.substr(0, idx).toLowerCase())] = StringUtil.trim(param.substr(idx + 1));
        }

        break;
      }

      return true;
    }

    public function getSessionBlock():Object {
      return this.sessionBlock;
    }

    public function getMediaBlock(mediaType:String):Object {
      return this.media[mediaType];
    }

    public function getMediaBlockByPayloadType(pt:int):Object {
      for each (var m:Object in this.media) {
        if (-1 !== m.fmt.indexOf(pt)) {
          return m;
        }
      }

      ErrorManager.dispatchError(826, [pt], true);

      return null;
    }

    public function getMediaBlockList():Array {
      var res:Array = [];
      for each (var m:Object in this.media) {
        res.push(m);
      }

      return res;
    }
  }
}
