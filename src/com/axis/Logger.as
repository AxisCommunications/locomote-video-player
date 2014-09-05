package com.axis {
  import flash.external.ExternalInterface;

  public class Logger {
    public static const STREAM_ERRORS:String = "";

    public static function log(message:String = null):void {
      if (Player.debugLogger.trace) {
        trace(message);
      }

      if (Player.debugLogger.js) {
        ExternalInterface.call("console.log", message);
      }
    }
  }
}
