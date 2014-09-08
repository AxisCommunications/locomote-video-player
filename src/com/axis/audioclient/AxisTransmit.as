package com.axis.audioclient {
  import com.axis.audioclient.IAudioClient;
  import com.axis.codec.g711;
  import com.axis.ErrorManager;
  import com.axis.http.auth;
  import com.axis.http.request;
  import com.axis.http.url;
  import com.axis.Logger;

  import flash.events.ErrorEvent;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SampleDataEvent;
  import flash.events.SecurityErrorEvent;
  import flash.events.StatusEvent;
  import flash.external.ExternalInterface;
  import flash.media.Microphone;
  import flash.media.SoundCodec;
  import flash.net.Socket;
  import flash.utils.ByteArray;

  public class AxisTransmit implements IAudioClient {
    private static const EVENT_AUDIO_TRANSMIT_STARTED:String = "audioTransmitStarted";
    private static const EVENT_AUDIO_TRANSMIT_STOPPED:String = "audioTransmitStopped";

    private var urlParsed:Object = {};
    private var conn:Socket = new Socket();

    private var authState:String = 'none';
    private var authOpts:Object = {};

    private var savedUrl:String = null;

    private var mic:Microphone = Microphone.getMicrophone();
    private var _microphoneVolume:Number;

    private var currentState:String = "stopped";

    public function AxisTransmit() {
      /* Set default microphone volume */
      this.microphoneVolume = 50;
    }

    private function onMicStatus(event:StatusEvent):void {
      if (conn.connected) {
        authState = 'none';
        conn.close();
      }

      if ('Microphone.Muted' === event.code) {
        ErrorManager.dispatchError(816);
        return;
      }

      if (urlParsed.host && urlParsed.port) {
        conn.connect(urlParsed.host, urlParsed.port);
      }
    }

    public function start(iurl:String = null):void {
      if (conn.connected) {
        ErrorManager.dispatchError(817);
        return;
      }

      var currentUrl:String = (iurl) ? iurl : savedUrl;

      if (!currentUrl) {
        ErrorManager.dispatchError(818);
        return;
      }

      this.savedUrl = currentUrl;

      var mic:Microphone = Microphone.getMicrophone();
      mic.rate = 16;
      mic.setSilenceLevel(0, -1);
      mic.addEventListener(StatusEvent.STATUS, onMicStatus);
      mic.addEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleData);

      this.urlParsed = url.parse(currentUrl);

      conn = new Socket();
      conn.addEventListener(Event.CONNECT, onConnected);
      conn.addEventListener(Event.CLOSE, onClosed);
      conn.addEventListener(ProgressEvent.SOCKET_DATA, onRequestData);
      conn.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
      conn.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);

      if (true === mic.muted) {
        ErrorManager.dispatchError(816);
        this.callAPI(EVENT_AUDIO_TRANSMIT_STOPPED);
        return;
      }

      conn.connect(urlParsed.host, urlParsed.port);
    }

    public function stop():void {
      if (!conn.connected) {
        ErrorManager.dispatchError(813);
        return;
      }

      mic.removeEventListener(StatusEvent.STATUS, onMicStatus);
      mic.removeEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleData);
      mic = null;
      conn.close();
    }

    private function writeAuthorizationHeader():void {
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
            authOpts.nonce,
            1
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
      conn.writeUTFBytes("Content-Type: audio/axis-mulaw-128\r\n");
      conn.writeUTFBytes("Content-Length: 9999999\r\n");
      conn.writeUTFBytes("Connection: Keep-Alive\r\n");
      conn.writeUTFBytes("Cache-Control: no-cache\r\n");
      writeAuthorizationHeader();
      conn.writeUTFBytes("\r\n");
    }

    public function onClosed(event:Event):void {
      if ("playing" === this.currentState) {
        this.currentState = "stopped";
        this.callAPI(EVENT_AUDIO_TRANSMIT_STOPPED);
      }
    }

    private function onMicSampleData(event:SampleDataEvent):void {
      if (!conn.connected) {
        return;
      }

      if ("stopped" === this.currentState) {
        this.currentState = "playing";
        this.callAPI(EVENT_TRANSMIT_AUDIO_STARTED);
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
          ErrorManager.dispatchError(parsed.code);
          return;
        }

        Logger.log('AxisTransmit: switching http-authorization from ' + authState + ' to ' + newAuthState);
        authState = newAuthState;
        conn.close();
        conn.connect(this.urlParsed.host, this.urlParsed.port);
        return;
      }
    }

    private function onIOError(event:IOErrorEvent):void {
      ErrorManager.dispatchError(732, [event.text]);
    }

    private function onSecurityError(event:SecurityErrorEvent):void {
      ErrorManager.dispatchError(731, [event.text]);
    }

    public function get microphoneVolume():Number {
      return _microphoneVolume;
    }

    public function set microphoneVolume(volume:Number):void {
      _microphoneVolume = volume;
      mic.gain = volume;

      if (volume && savedUrl)
        start();
    }

    public function muteMicrophone():void {
      mic.gain = 0;
      stop();
    }

    public function unmuteMicrophone():void {
      if (mic.gain !== 0)
        return;

      mic.gain = this.microphoneVolume;
      start();
    }

    private function callAPI(eventName:String, data:Object = null):void {
      var functionName:String = "Locomote('" + Player.locomoteID + "').__playerEvent";
      if (data) {
        ExternalInterface.call(functionName, eventName, data);
      } else {
        ExternalInterface.call(functionName, eventName);
      }
    }
  }
}
