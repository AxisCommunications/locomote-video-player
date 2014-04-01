package com.axis.rtspclient {

  import flash.events.ErrorEvent;
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.setTimeout;
  import flash.external.ExternalInterface;
  import flash.display.LoaderInfo;

  import mx.utils.ObjectUtil;

  import com.axis.rtspclient.ByteArrayUtils;
  import com.axis.rtspclient.GUID;
  import com.axis.rtspclient.RTSPClient;
  import com.axis.http.url;
  import com.axis.http.auth;
  import com.axis.http.request;

  [Event(name="connect", type="flash.events.Event")]
  [Event(name="disconnect", type="flash.events.Event")]

  public class HTTPClient extends EventDispatcher {

    public static var jsEventCallbackName:String = "console.log";
    private var getChannel:Socket = null;
    private var postChannel:Socket = null;
    private var urlParsed:Object = {};
    private var sessioncookie:String = "";

    private var authState:String = "none";
    private var authOpts:Object = {};
    private var digestNC:uint = 1;

    private var getChannelData:ByteArray;
    private var postChannelData:ByteArray;

    private var rtspClient:RTSPClient;

    public function HTTPClient() {
      sessioncookie = GUID.create();
      this.addEventListener('connected', onHTTPConnected);
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

    public function sendLoadedEvent():void {
      ExternalInterface.call(jsEventCallbackName, 'loaded');
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

      dispatchEvent(new Event("disconnect"));
    }

    public function connect(iurl:String = null):void {
      setupSockets();
      this.urlParsed = url.parse(iurl);
      getChannel.connect(this.urlParsed.host, this.urlParsed.port);
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
      postChannel.connect(this.urlParsed.host, this.urlParsed.port);
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

      dispatchEvent(new Event("connected"));
    }

    private function onHTTPConnected(event:Event):void {
      var handle:IRTSPHandle = new RTSPoverHTTPHandle(getChannel, postChannel);
      rtspClient = new RTSPClient(handle, this.urlParsed);
      rtspClient.start();
    }
  }
}
