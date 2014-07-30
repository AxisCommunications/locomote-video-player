package com.axis {
  import flash.external.ExternalInterface;

  public class ErrorManager {
    public static const NETSTREAM_CREATED:String = "NetStreamCreated";

    public static const STREAM_ERRORS:Object = {
      'nn': 'Generic error.'
    };

    public static function streamError(errorCode:Number, errorData:Array = null):void {
      var functionName:String = "Locomote('" + ExternalInterface.objectID + "').__playerEvent";
      var errorMessage:String = (errorData) ? ErrorManager.resolveErrorString(STREAM_ERRORS[errorCode], errorData) : STREAM_ERRORS[errorCode];
      var errorInfo:Object = {
        'code': errorCode,
        'message': errorMessage
      };
      ExternalInterface.call(functionName, "streamError", errorInfo);
    }

    public static function resolveErrorString(errorString:String, errorData:Array):String {
      var pattern:RegExp = /%p/;
      errorData.forEach(function(item:*, i:int, arr:Array):void {
        errorString = errorString.replace(pattern, item);
      });

      return errorString;
    }
  }
}