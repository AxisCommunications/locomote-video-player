package com.axis.rtspclient {
  import flash.utils.ByteArray;

  public class RTPTiming {

    public var rtpTime:Object;
    public var range:Object;
    public var live:Boolean;

    public function RTPTiming(rtpTime:Object, range:Object, live:Boolean) {
      this.rtpTime = rtpTime;
      this.range = range;
      this.live = live;
    }

    public function rtpTimeForControl(control:String):Number {
      /* control parameter and url in rtp-info may not equal but control
       * parameter is always part of the url */
      for (var c:String in this.rtpTime) {
        if (c.indexOf(control) >= 0) {
          return this.rtpTime[c];
        }
      }
      return 0;
    }

    public function toString():String {
      var res:String = 'rtpTime:';
      for (var control:String in rtpTime) {
        res += '\n  ' + control + ': ' + rtpTime[control];
      }
      if (range) {
        res += '\nrange: ' + range.from + ' - ' + range.to;
      }
      res += '\nlive: ' + live;
      return res;
    }

    public static function parse(rtpInfo:String, range:String):RTPTiming {
      var rtpTime:Object = {};
      for each (var track:String in rtpInfo.split(',')) {
        var rtpTimeMatch:Object = /^.*url=([^;]*);.*rtptime=(\d+).*$/.exec(track);
        rtpTime[rtpTimeMatch[1]] = parseInt(rtpTimeMatch[2]);
      }
      var rangeMatch:Object = /^npt=(.*)-(.*)$/.exec(range);
      var rangeFrom:String = rangeMatch[1];
      var rangeTo:String = rangeMatch[2];
      var from:Number = 0;
      var to:Number = rangeTo.length > 0 ? Math.round(parseFloat(rangeTo) * 1000) : -1;
      var live:Boolean = rangeFrom == 'now';
      if (rangeFrom != 'now') {
        from = Math.round(parseFloat(rangeFrom) * 1000);
        /* Some idiot RTSP servers writes Range: npt=0.000-0.000 in the header... */
        to = to <= from ? -1 : to;
      }

      return new RTPTiming(rtpTime, { from: from, to: to }, live);
    }
  }
}
