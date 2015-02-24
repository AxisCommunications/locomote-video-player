package com.axis {
  import flash.external.ExternalInterface;

  public class Logger {
    public static const STREAM_ERRORS:String = "";

    public static function log(... args):void {
      if (Player.config.debugLogger) {
        trace.apply(null, args);
      }

      var functionName:String = "LocomoteMap['" + Player.locomoteID + "'].__playerEvent";
      args.unshift(functionName, 'log');
      ExternalInterface.call.apply(ExternalInterface, args);
    }
  }
}
