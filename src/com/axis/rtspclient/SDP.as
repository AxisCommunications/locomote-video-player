package com.axis.rtspclient {

  import flash.utils.ByteArray;
  import flash.external.ExternalInterface;

  public class SDP {

    private var tracks:Vector.<String> = new Vector.<String>();

    public function SDP()
    {
    }

    public function parse(content:ByteArray):Boolean
    {
      var dataString:String = content.toString();
      var matches:Array = dataString.match(/a=control:(.*)/g);
      if (0 === matches.length) {
        return false;
      }

      for each (var match:String in matches) {
        tracks.push(match.replace("a=control:", ""));
      }

      return true;
    }

    public function getTrack():String
    {
      return tracks[tracks.length - 1];
    }
  }
}
