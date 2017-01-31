package com.axis.rtspclient {
  import com.axis.ErrorManager;
  import com.axis.http.request;
  import com.axis.Logger;
  import com.axis.rtspclient.GUID;

  import flash.events.Event;
  import flash.events.HTTPStatusEvent;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.events.TimerEvent;

  import flash.net.URLStream;
  import flash.net.URLLoader;
  import flash.net.URLRequest;
  import flash.utils.ByteArray;
  import flash.utils.*;

  import mx.utils.Base64Encoder;

  public class RTSPoverHTTPAPHandle extends EventDispatcher implements IRTSPHandle {
    private var getChannel:URLStream = null;
    private var poster:URLLoader = null;
    private var urlParsed:Object;
    private var sessioncookie:String;
    private var url:String;
    private var connectTimer:Timer;

    private var base64encoder:Base64Encoder;

    private var secure:Boolean;

    public function RTSPoverHTTPAPHandle(urlParsed:Object, secure:Boolean) {
      this.sessioncookie = GUID.create();
      this.urlParsed = urlParsed;
      this.url = 'https://' + this.urlParsed.host + this.urlParsed.urlpath + "?sessioncookie=" + this.sessioncookie;
      this.base64encoder = new Base64Encoder();
      this.secure = secure;
      this.getChannel = new URLStream();
      this.getChannel.addEventListener(ProgressEvent.PROGRESS, onData);
      this.getChannel.addEventListener(Event.OPEN, onOpen);
      this.getChannel.addEventListener(Event.COMPLETE, onComplete);
      this.getChannel.addEventListener(HTTPStatusEvent.HTTP_STATUS, onStatus);
      this.getChannel.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
      this.getChannel.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
    }

    public function writeUTFBytes(value:String):void {
      var data:String = base64encode(value);
      var req:URLRequest = new URLRequest(this.url);
      req.method = 'POST';
      req.data = data;
      req.contentType = 'application/x-rtsp-tunnelled';

      this.poster = new URLLoader();
      this.poster.addEventListener(IOErrorEvent.IO_ERROR, function ():void {});
      this.poster.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function ():void {});
      this.poster.load(req);
    }

    public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void {
      this.getChannel.readBytes(bytes, offset, length);
    }

    public function disconnect():void {
      if (this.getChannel.connected) {
        this.getChannel.close();
        this.getChannel.removeEventListener(ProgressEvent.PROGRESS, onData);
        this.getChannel.removeEventListener(Event.OPEN, onOpen);
        this.getChannel.removeEventListener(Event.COMPLETE, onComplete);
        this.getChannel.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onStatus);
        this.getChannel.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
        this.getChannel.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
      }

      /* should probably wait for close, but it doesn't seem to fire properly */
      dispatchEvent(new Event('closed'));
    }

    public function connect():void {
      var req:URLRequest = new URLRequest(this.url);
      Logger.log('RTSP+HTTP+AxisProxy connecting to', req.url);
      this.getChannel.load(req);
    }

    public function reconnect():void {
      if (getChannel.connected) {
        getChannel.close();
      }
      connect();
    }

    public function cmdReceived():void {
      if (this.poster) {
        // Close the previous POST request
        this.poster.close();
        this.poster.removeEventListener(IOErrorEvent.IO_ERROR, function ():void {});
        this.poster.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, function ():void {});
      }
    }

    private function onComplete(event:Event):void {
      dispatchEvent(new Event('closed'));
    }

    private function onOpen(event:Event):void {
      Logger.log('RTSP+HTTP+AxisProxy connected to', 'http://' + this.urlParsed.host +
          this.urlParsed.urlpath + "?sessioncookie=" + sessioncookie);
      if(Player.isUserAgentIE()) {
          // IE/Edge workaround. getChannel OPEN event is emitted prematurely.
          // This causes the following POST request to be sent before the GET channel is established.
          // Add a delay to give some time for the GET connection to be established.
          this.connectTimer = new Timer(1000, 1);
          this.connectTimer.addEventListener(TimerEvent.TIMER, connectedDelay);
          this.connectTimer.start();
        } else {
          dispatchEvent(new Event('connected'));
        }
    }

    private function connectedDelay(e:TimerEvent):void {
      dispatchEvent(new Event('connected'));
    }

    private function onData(event:ProgressEvent):void {
      dispatchEvent(new Event('data'));
    }

    private function onStatus(event:HTTPStatusEvent):void {
      if (event.status !== 200) {
        ErrorManager.dispatchError(event.status);
      }
    }

    private function onIOError(event:IOErrorEvent):void {
      ErrorManager.dispatchError(732, [event.text]);
      dispatchEvent(new Event('closed'));
    }

    private function onSecurityError(event:SecurityErrorEvent):void {
      ErrorManager.dispatchError(731, [event.text]);
      dispatchEvent(new Event('closed'));
    }

    private function base64encode(str:String):String {
      base64encoder.reset();
      base64encoder.insertNewLines = false;
      base64encoder.encode(str);
      return base64encoder.toString();
    }
  }
}
