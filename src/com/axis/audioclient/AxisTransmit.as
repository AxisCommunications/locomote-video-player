package com.axis.audioclient {

  import flash.events.Event;
  import flash.events.ProgressEvent;
  import flash.events.ErrorEvent;
  import flash.events.SampleDataEvent;
  import flash.events.StatusEvent;
  import flash.events.SecurityErrorEvent;
  import flash.events.IOErrorEvent;
  import flash.net.Socket;
  import flash.media.Microphone;
  import flash.media.SoundCodec;
  import flash.utils.ByteArray;

  import com.axis.codec.g711;
  import com.axis.http.url;
  import com.axis.http.auth;
  import com.axis.http.request;

  public class AxisTransmit {
    private var urlParsed:Object = {};
    private var conn:Socket = new Socket();

    private var authState:String = 'none';
    private var authOpts:Object = {};

    public function AxisTransmit() {
    }

    private function onMicStatus(event:StatusEvent):void {
      if (conn.connected) {
        authState = 'none';
        conn.close();
      }

      if ('Microphone.Muted' === event.code) {
        trace('AxisTransmit: Denied access to microphone');
        return;
      }

      if (urlParsed.host && urlParsed.port) {
        conn.connect(urlParsed.host, urlParsed.port);
      }
    }

    public function start(iurl:String):void {
      if (conn.connected) {
        trace('already connected');
        return;
      }

      var mic:Microphone = Microphone.getMicrophone();
      mic.rate = 8;
      mic.setSilenceLevel(0, -1);
      mic.addEventListener(StatusEvent.STATUS, onMicStatus);
      mic.addEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleData);

      this.urlParsed = url.parse(iurl);

      conn = new Socket();
      conn.addEventListener(Event.CONNECT, onConnected);
      conn.addEventListener(Event.CLOSE, onClosed);
      conn.addEventListener(ProgressEvent.SOCKET_DATA, onRequestData);
      conn.addEventListener(IOErrorEvent.IO_ERROR, onError);
      conn.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);

      if (true === mic.muted) {
        trace('Not allowed access to microphone, delay connect');
        return;
      }

      conn.connect(urlParsed.host, urlParsed.port);
    }

    public function stop():void {
      if (!conn.connected) {
        trace('not connected');
        return;
      }

      var mic:Microphone = Microphone.getMicrophone();
      mic.removeEventListener(StatusEvent.STATUS, onMicStatus);
      mic.removeEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleData);
      conn.close();
    }

    private function writeAuthorizationHeader():void
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
            "POST",
            authOpts.digestRealm,
            urlParsed.urlpath,
            authOpts.qop,
            authOpts.nonce
          );
          break;

        default:
        case "none":
          return;
      }

      conn.writeUTFBytes('Authorization: ' + a + "\r\n");
    }


    private function onConnected(event:Event):void {
      conn.writeUTFBytes("POST " + this.urlParsed.urlpath + " HTTP/1.0\r\n");
      conn.writeUTFBytes("Content-Type: audio/basic\r\n");
      conn.writeUTFBytes("Content-Length: 9999999\r\n");
      conn.writeUTFBytes("Connection: Keep-Alive\r\n");
      conn.writeUTFBytes("Cache-Control: no-cache\r\n");
      writeAuthorizationHeader();
      conn.writeUTFBytes("\r\n");
    }

    private function onClosed(event:Event):void {
      trace('axis audio closed');
    }

    private function onMicSampleData(event:SampleDataEvent):void
    {
      if (!conn.connected) {
        return;
      }

      while (event.data.bytesAvailable) {
        var encoded:uint = g711.linearToMulaw(event.data.readFloat());
        conn.writeByte(encoded);
      }

      conn.flush();
    }

    private function onRequestData(event:ProgressEvent):void {
      var data:ByteArray = new ByteArray();
      var parsed:* = request.readHeaders(conn, data);

      if (false === parsed) {
        return;
      }

     if (401 === parsed.code) {
        /* Unauthorized, change authState and (possibly) try again */
        authOpts = parsed.headers['www-authenticate'];
        var newAuthState:String = auth.nextMethod(authState, authOpts);
        if (authState === newAuthState) {
          trace('AxisTransmit: Exhausted all authentication methods.');
          trace('AxisTransmit: Unable to authorize to ' + urlParsed.host);
          return;
        }

        trace('AxisTransmit: switching http-authorization from ' + authState + ' to ' + newAuthState);
        authState = newAuthState;
        conn.close();
        conn.connect(this.urlParsed.host, this.urlParsed.port);
        return;
      }

    }

    private function onError(e:ErrorEvent):void {
      trace('axis transmit error');
    }
  }
}
