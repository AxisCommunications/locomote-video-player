package com.axis {
  import flash.external.ExternalInterface;

  public class Logger {
    public static const STREAM_ERRORS:String = "";

    public static function log(message:String = null):void {
      if (Player.debugLogger) {
        trace(message);
      }

      var functionName:String = "Locomote('" + Player.locomoteID + "').__playerEvent";
      ExternalInterface.call(functionName, 'log', message);
    }
  }
}
