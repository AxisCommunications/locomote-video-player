package com.axis.rtspclient {

  import flash.events.ErrorEvent;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import mx.utils.Base64Encoder;

  import com.axis.rtspclient.GUID;
  import com.axis.http.url;
  import com.axis.http.auth;
  import com.axis.http.request;

  public class RTSPoverHTTPHandle implements IRTSPHandle {

    private var getChannel:Socket = null;
    private var postChannel:Socket = null;
    private var urlParsed:Object = {};
    private var sessioncookie:String = "";

    private var base64encoder:Base64Encoder;

    private var datacb:Function = null;
    private var connectcb:Function = null;

    private var authState:String = "none";
    private var authOpts:Object = {};
    private var digestNC:uint = 1;

    private var getChannelData:ByteArray;
    private var postChannelData:ByteArray;

    public function RTSPoverHTTPHandle(urlParsed:Object) {
      this.sessioncookie = GUID.create();
      this.urlParsed = urlParsed;
      this.base64encoder = new Base64Encoder();
    }

    private function setupSockets():void
    {
      getChannel = new Socket();
      getChannel.timeout = 5000;
      getChannel.addEventListener(Event.CONNECT, onGetChannelConnect);
      getChannel.addEventListener(Event.CLOSE, onGetChannelClose);
      getChannel.addEventListener(ProgressEvent.SOCKET_DATA, onGetChannelData);
      getChannel.addEventListener(IOErrorEvent.IO_ERROR, onError);
      getChannel.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);

      postChannel = new Socket();
      postChannel.timeout = 5000;
      postChannel.addEventListener(Event.CONNECT, onPostChannelConnect);
      postChannel.addEventListener(Event.CLOSE, onPostChannelClose);
      postChannel.addEventListener(IOErrorEvent.IO_ERROR, onError);
      postChannel.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);

      getChannelData = new ByteArray();
      postChannelData = new ByteArray();
    }

    private function base64encode(str:String):String {
      base64encoder.reset();
      base64encoder.insertNewLines = false;
      base64encoder.encode(str);
      return base64encoder.toString();
    }

    public function writeUTFBytes(value:String):void
    {
      postChannel.writeUTFBytes(base64encode(value));
      postChannel.flush();
    }

    public function readBytes(bytes:ByteArray, offset:uint = 0, length:uint = 0):void
    {
      getChannel.readBytes(bytes, offset, length);
    }

    public function onData(cb:Function):void {
      this.datacb = cb;
    }

    public function onConnect(cb:Function):void {
      this.connectcb = cb;
    }

    private function onError(e:ErrorEvent):void {
      trace("HTTPClient socket error");
    }

    public function disconnect():void {
      if (getChannel && getChannel.connected) {
        getChannel.close();
      }
      if (postChannel && postChannel.connected) {
        postChannel.close();
      }
    }

    public function connect():void {
      setupSockets();
      getChannel.connect(this.urlParsed.host, this.urlParsed.port);
    }

    public function reconnect():void
    {
      trace('RTSPoverHTTPHandle: reconnect not implemented');
    }

    private function onGetChannelConnect(event:Event):void {
      trace("get channel connected");
      initializeGetChannel();
    }

    private function onPostChannelConnect(event:Event):void {
      trace("post channel connected");
      initializePostChannel();
    }

    public function stop():void {
      disconnect();
    }

    private function onGetChannelClose(event:Event):void
    {
      trace('GET channel closed');
    }

    private function onPostChannelClose(event:Event):void
    {
      trace('POST channel closed');
    }

    private function onGetChannelData(event:ProgressEvent):void {
      var parsed:* = request.readHeaders(getChannel, getChannelData);
      if (false === parsed) {
        return;
      }

      if (401 === parsed.code) {
        /* Unauthorized, change authState and (possibly) try again */
        authOpts = parsed.headers['www-authenticate'];
        var newAuthState:String = auth.nextMethod(authState, authOpts);
        if (authState === newAuthState) {
          trace('GET: Exhausted all authentication methods.');
          trace('GET: Unable to authorize to ' + urlParsed.host);
          return;
        }

        trace('switching http-authorization from ' + authState + ' to ' + newAuthState);
        authState = newAuthState;
        getChannelData = new ByteArray();
        getChannel.close();
        getChannel.connect(this.urlParsed.host, this.urlParsed.port);
        return;
      }

      if (200 !== parsed.code) {
        trace('Invalid HTTP code: ' + parsed.code);
        return;
      }

      getChannel.removeEventListener(ProgressEvent.SOCKET_DATA, onGetChannelData);
      getChannel.addEventListener(ProgressEvent.SOCKET_DATA, onGetChannelDataPassthroguh);
      postChannel.connect(this.urlParsed.host, this.urlParsed.port);
    }

    private function onGetChannelDataPassthroguh(event:ProgressEvent):void
    {
      if (null !== this.datacb) this.datacb();
    }

    private function writeAuthorizationHeader(method:String, channel:Socket):void
    {
      var a:String = '';
      switch (authState) {
        case "basic":
          a = auth.basic(this.urlParsed.user, this.urlParsed.pass) + "\r\n";
          break;

        case "digest":
          a = auth.digest(
            this.urlParsed.user,
            this.urlParsed.pass,
            method,
            authOpts.digestRealm,
            urlParsed.urlpath,
            authOpts.qop,
            authOpts.nonce,
            digestNC++
          );
          break;

        default:
        case "none":
          return;
      }

      channel.writeUTFBytes('Authorization: ' + a + "\r\n");
    }

    private function initializeGetChannel():void {
      trace("Sending: GET");
      getChannel.writeUTFBytes("GET " + urlParsed.urlpath + " HTTP/1.0\r\n");
      getChannel.writeUTFBytes("X-Sessioncookie: " +  sessioncookie + "\r\n");
      getChannel.writeUTFBytes("Accept: application/x-rtsp-tunnelled\r\n");
      writeAuthorizationHeader("GET", getChannel);
      getChannel.writeUTFBytes("\r\n");
      getChannel.flush();
    }

    private function initializePostChannel():void {
      trace("Sending: POST");
      postChannel.writeUTFBytes("POST " + urlParsed.urlpath + " HTTP/1.0\r\n");
      postChannel.writeUTFBytes("X-Sessioncookie: " + sessioncookie + "\r\n");
      postChannel.writeUTFBytes("Content-Length: 32767" + "\r\n");
      postChannel.writeUTFBytes("Content-Type: application/x-rtsp-tunnelled" + "\r\n");
      writeAuthorizationHeader("POST", postChannel);
      postChannel.writeUTFBytes("\r\n");
      postChannel.flush();

      if (null !== this.connectcb) connectcb();
    }
  }
}
