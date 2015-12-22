package com.axis {
  import flash.display.LoaderInfo;
  import flash.external.ExternalInterface;

  public class ErrorManager {
    public static const STREAM_ERRORS:Object = {
      '100': "Continue",
      '200': "OK",
      '201': "Created",
      '250': "Low on Storage Space",
      '300': "Multiple Choices",
      '301': "Moved Permanently",
      '302': "Moved Temporarily",
      '303': "See Other",
      '304': "Not Modified",
      '305': "Use Proxy",
      '400': "Bad Request",
      '401': "Unauthorized",
      '402': "Payment Required",
      '403': "Forbidden",
      '404': "Not Found",
      '405': "Method Not Allowed",
      '406': "Not Acceptable",
      '407': "Proxy Authentication Required",
      '408': "Request Time-out",
      '410': "Gone",
      '411': "Length Required",
      '412': "Precondition Failed",
      '413': "Request Entity Too Large",
      '414': "Request-URI Too Large",
      '415': "Unsupported Media Type",
      '451': "Parameter Not Understood",
      '452': "Conference Not Found",
      '453': "Not Enough Bandwidth",
      '454': "Session Not Found",
      '455': "Method Not Valid in This State",
      '456': "Header Field Not Valid for Resource",
      '457': "Invalid Range",
      '458': "Parameter Is Read-Only",
      '459': "Aggregate operation not allowed",
      '460': "Only aggregate operation allowed",
      '461': "Unsupported transport",
      '462': "Destination unreachable",
      '463': "Key management Failure",
      '500': "Internal Server Error",
      '501': "Not Implemented",
      '502': "Bad Gateway",
      '503': "Service Unavailable",
      '504': "Gateway Time-out",
      '505': "RTSP Version not supported",
      '551': "Option not supported",
      '700': "NetConnection.Call.BadVersion - Packet encoded in an unidentified format.",
      '701': "NetConnection.Call.Failed - The NetConnection.call() method was not able to invoke the server-side method or command.",
      '702': "NetConnection.Call.Prohibited - An Action Message Format (AMF) operation is prevented for security reasons. Either the AMF URL is not in the same domain as the file containing the code calling the NetConnection.call() method, or the AMF server does not have a policy file that trusts the domain of the the file containing the code calling the NetConnection.call() method.",
      '703': "NetConnection.Connect.AppShutdown - The server-side application is shutting down.",
      '704': "NetConnection.Connect.Failed - The connection attempt failed.",
      '705': "NetConnection.Connect.InvalidApp - The application name specified in the call to NetConnection.connect() is invalid.",
      '706': "NetConnection.Connect.Rejected - The connection attempt did not have permission to access the application.",
      '707': "NetGroup.Connect.Failed - The NetGroup connection attempt failed. The info.group property indicates which NetGroup failed.",
      '708': "NetGroup.Connect.Rejected - The NetGroup is not authorized to function. The info.group property indicates which NetGroup was denied.",
      '709': "NetStream.Connect.Failed - The P2P connection attempt failed. The info.stream property indicates which stream has failed. Note: Not supported in AIR 3.0 for iOS.",
      '710': "NetStream.Connect.Rejected - The P2P connection attempt did not have permission to access the other peer. The info.stream property indicates which stream was rejected. Note: Not supported in AIR 3.0 for iOS.",
      '711': "NetStream.Failed - (Flash Media Server) An error has occurred for a reason other than those listed in other event codes.",
      '712': "NetStream.Play.Failed - An error has occurred in playback for a reason other than those listed elsewhere in this table, such as the subscriber not having read access. Note: Not supported in AIR 3.0 for iOS.",
      '713': "NetStream.Play.FileStructureInvalid - (AIR and Flash Player 9.0.115.0) The application detects an invalid file structure and will not try to play this type of file. Note: Not supported in AIR 3.0 for iOS.",
      '714': "NetStream.Play.InsufficientBW - (Flash Media Server) The client does not have sufficient bandwidth to play the data at normal speed. Note: Not supported in AIR 3.0 for iOS.",
      '715': "NetStream.Play.StreamNotFound - The file passed to the NetStream.play() method can't be found.",
      '716': "NetStream.Publish.BadName - Attempt to publish a stream which is already being published by someone else.",
      '717': "NetStream.Record.Failed - An attempt to record a stream failed.",
      '718': "NetStream.Record.NoAccess - Attempt to record a stream that is still playing or the client has no access right.",
      '719': "NetStream.Seek.Failed - The seek fails, which happens if the stream is not seekable.",
      '720': "NetStream.Seek.InvalidTime - For video downloaded progressively, the user has tried to seek or play past the end of the video data that has downloaded thus far, or past the end of the video once the entire file has downloaded. The info.details property of the event object contains a time code that indicates the last valid position to which the user can seek.",
      '721': "SharedObject.BadPersistence - A request was made for a shared object with persistence flags, but the request cannot be granted because the object has already been created with different flags.",
      '722': "SharedObject.Flush.Failed - The 'pending' status is resolved, but the SharedObject.flush() failed.",
      '723': "SharedObject.UriMismatch - The video dimensions are available or have changed. Use the Video or StageVideo videoWidth/videoHeight property to query the new video dimensions. New in Flash Player 11.4/AIR 3.4.",
      '724': "Unknown NetStatus error: %p",
      '725': "NetStream reported an asyncError: %p",
      '726': "NetStream reported a DRMError with ID: %p and subID: %p.",
      '727': "NetStream reported an IOError: %p.",
      '728': "NetConnection reported an asyncError.",
      '729': "NetConnection reported an IOError: %p.",
      '730': "NetConnection reported a security error: %p.",
      '731': "Socket reported a security error: %p.",
      '732': "Socket reported an IOError: %p.",
      '800': "Unable to pause a stream if not playing.",
      '801': "Unable to resume a stream if not paused.",
      '802': "################### Unused",
      '803': "RTSPClient: Handle unexpectedly closed.",
      '804': "Unknown determining byte: 0x%p. Stopping stream.",
      '805': "Cannot start unless in initial state.",
      '806': "RTSPClient:Failed to parse SDP file.",
      '807': "No tracks in SDP file.",
      '808': "Unable to pause. This might not work for this stream-type, or this particular stream.",
      '809': "Unable to resume. This might not work for this stream-type, or this particular stream.",
      '810': "Unable to stop. This might not work for this stream-type, or this particular stream.",
      '811': "Unknown streaming protocol: %p",
      '812': "Unsupported audio transmit protocol.",
      '813': "Denied access to microphone.",
      '814': "Already connected to microphone.",
      '815': "No audio transmit url provided.",
      '816': "Denied access to microphone.",
      '817': "Audio transmit already connected.",
      '818': "No audio transmit url provided.",
      '819': "BitArray: Bit ranges must be 1 - 32.",
      '820': "BitArray: exp-golomb larger than 32 bits is unsupported.",
      '821': "ByteArray: Unsupported Pattern",
      '822': "FLVMux: No support for Chroma/Luma scaling matrix",
      '823': "FLVMux: No support for parsing 'pic_order_cnt_type' != 0",
      '824': "RTSPClient: Unable to determine control URL.",
      '825': "RTSPClient: Pause is not supported by server.",
      '826': "No media block for payload type: %p",
      '827': "Connection broken. The stream has been stopped.",
      '828': "Unable to seek.",
      '829': "httpm only supports Content-Type: 'multipart/x-mixed-replace'",
      '830': "Unable to set buffer. This might not work for this stream-type, or this particular stream.",
      '831': "Unsupported Audio or Video format: %p",
      '832': "Unable to set frame by frame. This might not work for this stream-type, or this particular stream.",
      '833': "Failed to load mjpeg image.",
      '834': "Unable to set keep alive interval"
    };

    public static function dispatchError(errorCode:Number, errorData:Array = null, throwError:Boolean = false):void {
      var functionName:String = "LocomoteMap['" + Player.locomoteID + "'].__playerEvent";
      var errorMessage:String = (errorData) ? ErrorManager.resolveErrorString(STREAM_ERRORS[errorCode], errorData) : STREAM_ERRORS[errorCode];
      if (null === errorMessage) {
        errorMessage = "An unknown error has occurred.";
      }
      var errorInfo:Object = {
        'code': errorCode,
        'message': errorMessage
      };
      ExternalInterface.call(functionName, "error", errorInfo);
      if (throwError) {
        throw new Error(errorMessage);
      }
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
