package com.axis.rtspclient {
  import com.axis.ClientEvent;
  import com.axis.ErrorManager;
  import com.axis.http.auth;
  import com.axis.http.request;
  import com.axis.http.url;
  import com.axis.Logger;
  import com.axis.rtspclient.GUID;

  import flash.events.ErrorEvent;
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.net.Socket;
  import flash.net.SecureSocket;
  import flash.utils.ByteArray;
  import flash.utils.*;

  import mx.utils.Base64Encoder;

  public class RTSPoverHTTPHandle extends EventDispatcher implements IRTSPHandle {
    private var getChannel:Socket = null;
    private var urlParsed:Object = {};
    private var sessioncookie:String = "";

    private var base64encoder:Base64Encoder;

    private var secure:Boolean;

    private var datacb:Function = null;
    private var connectcb:Function = null;

    private var authState:String = "none";
    private var authOpts:Object = {};
    private var digestNC:uint = 1;

    private var getChannelData:ByteArray;

    public function RTSPoverHTTPHandle(urlParsed:Object, secure:Boolean) {
      this.sessioncookie = GUID.create();
      this.urlParsed = urlParsed;
      this.base64encoder = new Base64Encoder();
      this.secure = secure;
    }

    private function setupSockets():void {
      getChannel = this.secure ? new SecureSocket() : new Socket();
      getChannel.timeout = 5000;
      getChannel.addEventListener(Event.CONNECT, onGetChannelConnect);
      getChannel.addEventListener(ProgressEvent.SOCKET_DATA, onGetChannelData);
      getChannel.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
      getChannel.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);

      getChannelData = new ByteArray();
    }

    private function base64encode(str:String):String {
      base64encoder.reset();
      base64encoder.insertNewLines = false;
      base64encoder.encode(str);
      return base64encoder.toString();
    }

    public function writeUTFBytes(value:String):void {
      var data:String = base64encode(value);
      var authHeader:String = auth.authorizationHeader("POST", authState, authOpts, urlParsed, digestNC++);
      var socket:Socket = this.secure ? new SecureSocket() : new Socket();
      socket.timeout = 5000;
      socket.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
      socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);

      socket.addEventListener(Event.CONNECT, function ():void {
        socket.writeUTFBytes("POST " + urlParsed.urlpath + " HTTP/1.0\r\n");
        socket.writeUTFBytes("x-sessioncookie: " + sessioncookie + "\r\n");
        socket.writeUTFBytes("Content-Length: " + data.length + "\r\n");
        socket.writeUTFBytes("Content-Type: application/x-rtsp-tunnelled" + "\r\n");
        socket.writeUTFBytes(authHeader);
        socket.writeUTFBytes("\r\n");

        socket.writeUTFBytes(data);
        socket.flush();

        // Timeout required before close to let the data actually be written to
        // the socket. Flush appears to be asynchronous...
        setTimeout(socket.close, 5000);
      });


      socket.connect(this.urlParsed.host, this.urlParsed.port);
    }

    public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void {
      getChannel.readBytes(bytes, offset, length);
    }

    public function disconnect():void {
      if (getChannel.connected) {
        getChannel.close();

        getChannel.removeEventListener(Event.CONNECT, onGetChannelConnect);
        getChannel.removeEventListener(ProgressEvent.SOCKET_DATA, onGetChannelData);
        getChannel.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
        getChannel.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
      }

      /* should probably wait for close, but it doesn't seem to fire properly */
      dispatchEvent(new Event('closed'));
    }

    public function connect():void {
      setupSockets();
      Logger.log('RTSP+HTTP' + (this.secure ? 'S' : '') + 'connecting to', this.urlParsed.host + ':' + this.urlParsed.port);
      getChannel.connect(this.urlParsed.host, this.urlParsed.port);
    }

    public function reconnect():void {
      if (getChannel.connected) {
        getChannel.close();
      }
      connect();
    }

    private function onGetChannelConnect(event:Event):void {
      initializeGetChannel();
    }

    public function stop():void {
      disconnect();
    }

    private function onGetChannelData(event:ProgressEvent):void {
      var parsed:* = request.readHeaders(getChannel, getChannelData);
      if (false === parsed) {
        return;
      }

      if (401 === parsed.code) {
        Logger.log('Unauthorized using auth method: ' + authState);
        /* Unauthorized, change authState and (possibly) try again */
        authOpts = parsed.headers['www-authenticate'];
        var newAuthState:String = auth.nextMethod(authState, authOpts);
        if (authState === newAuthState) {
          ErrorManager.dispatchError(parsed.code);
          return;
        }

        Logger.log('switching http-authorization from ' + authState + ' to ' + newAuthState);
        authState = newAuthState;
        getChannelData = new ByteArray();
        getChannel.close();
        getChannel.connect(this.urlParsed.host, this.urlParsed.port);
        return;
      }

      if (200 !== parsed.code) {
        ErrorManager.dispatchError(parsed.code);
        return;
      }

      getChannel.removeEventListener(ProgressEvent.SOCKET_DATA, onGetChannelData);
      getChannel.addEventListener(ProgressEvent.SOCKET_DATA, function(ev:ProgressEvent):void {
        dispatchEvent(new Event('data'));
      });

      dispatchEvent(new Event('connected'));
    }

    private function initializeGetChannel():void {
      getChannel.writeUTFBytes("GET " + urlParsed.urlpath + " HTTP/1.0\r\n");
      getChannel.writeUTFBytes("x-sessioncookie: " +  sessioncookie + "\r\n");
      getChannel.writeUTFBytes("Range: bytes=0-\r\n");
      getChannel.writeUTFBytes("Accept: application/x-rtsp-tunnelled\r\n");
      getChannel.writeUTFBytes(auth.authorizationHeader("GET", authState, authOpts, urlParsed, digestNC++));
      getChannel.writeUTFBytes("\r\n");
      getChannel.flush();
    }

    private function onIOError(event:IOErrorEvent):void {
      ErrorManager.dispatchError(732, [event.text]);
      dispatchEvent(new Event('closed'));
    }

    private function onSecurityError(event:SecurityErrorEvent):void {
      ErrorManager.dispatchError(731, [event.text]);
      dispatchEvent(new Event('closed'));
    }
  }
}
