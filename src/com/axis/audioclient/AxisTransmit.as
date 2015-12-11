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
  import flash.net.SecureSocket;
  import flash.utils.ByteArray;

  public class AxisTransmit implements IAudioClient {
    private static const EVENT_AUDIO_TRANSMIT_STARTED:String = 'audioTransmitStarted';
    private static const EVENT_AUDIO_TRANSMIT_STOPPED:String = 'audioTransmitStopped';
    private static const EVENT_AUDIO_TRANSMIT_REQUEST_PERMISSION:String = 'audioTransmitRequestPermission';
    private static const EVENT_AUDIO_TRANSMIT_ALLOWED:String = 'audioTransmitAllowed';
    private static const EVENT_AUDIO_TRANSMIT_DENIED:String = 'audioTransmitDenied';

    private var urlParsed:Object = {};
    private var conn:Socket;

    private var authState:String = 'none';
    private var authOpts:Object = {};

    private var savedUrl:String = null;

    private var mic:Microphone;
    private var _microphoneVolume:Number;
    private var permissionResovled:Boolean = false;

    private var currentState:String = 'stopped';

    public function AxisTransmit() {
      /* Set default microphone volume */
      this.microphoneVolume = 50;
    }

    private function onMicSampleDummy(event:SampleDataEvent):void {}

    private function onMicStatus(event:StatusEvent):void {
      Logger.log("AxisTransmit: MicStatus", { event: event.code });

      this.permissionResovled = true;
      this.mic.removeEventListener(StatusEvent.STATUS, onMicStatus);
      this.mic.removeEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleDummy);

      switch (event.code) {
      case 'Microphone.Muted':
        this.callAPI(EVENT_AUDIO_TRANSMIT_DENIED);
        break;
      case 'Microphone.Unmuted':
        this.callAPI(EVENT_AUDIO_TRANSMIT_ALLOWED);
        break;
      }
    }

    public function start(iurl:String = null):void {
      if (conn && conn.connected) {
        ErrorManager.dispatchError(817);
        return;
      }

      this.currentState = 'initial';

      var currentUrl:String = (iurl) ? iurl : savedUrl;

      if (!currentUrl) {
        ErrorManager.dispatchError(818);
        return;
      }

      this.urlParsed = url.parse(currentUrl);
      this.savedUrl = currentUrl;

      this.mic = Microphone.getMicrophone();

      if (null === this.mic) {
        ErrorManager.dispatchError(819);
        return;
      }

      this.mic.rate = 16;
      this.mic.setSilenceLevel(0, -1);

      conn = this.urlParsed.protocol == 'https' ? new SecureSocket() : new Socket();
      conn.addEventListener(Event.CONNECT, onConnected);
      conn.addEventListener(Event.CLOSE, onClosed);
      conn.addEventListener(ProgressEvent.SOCKET_DATA, onRequestData);
      conn.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
      conn.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);

      if (this.mic.muted) {
        if (this.permissionResovled) {
          ErrorManager.dispatchError(816);
        } else {
          this.mic.addEventListener(StatusEvent.STATUS, onMicStatus);
          this.mic.addEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleDummy);
          this.callAPI(EVENT_AUDIO_TRANSMIT_REQUEST_PERMISSION);
        }
      } else {
        this.connect();
      }
    }

    public function stop():void {
      this.close();
    }

    private function connect():void {
      if (!conn.connected) {
        Logger.log("AxisTransmit: Connecting to ", this.urlParsed.host + ":" + this.urlParsed.port);
        conn.connect(this.urlParsed.host, this.urlParsed.port);
      }
    }

    private function onConnected(event:Event):void {
      Logger.log("AxisTransmit: Connected to ", this.urlParsed.host + ":" + this.urlParsed.port);

      this.mic.addEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleData);

      conn.writeUTFBytes("POST " + this.urlParsed.urlpath + " HTTP/1.0\r\n");
      conn.writeUTFBytes("Content-Type: audio/axis-mulaw-128\r\n");
      conn.writeUTFBytes("Content-Length: 9999999\r\n");
      conn.writeUTFBytes("Connection: Keep-Alive\r\n");
      conn.writeUTFBytes("Cache-Control: no-cache\r\n");
      writeAuthorizationHeader();
      conn.writeUTFBytes("\r\n");
    }

    private function close():void {
      if (conn.connected) {
        Logger.log("AxisTransmit: Disconnecting from ", this.urlParsed.host + ":" + this.urlParsed.port);
        conn.close();
        this.onClosed();
      }
    }

    private function onClosed(event:Event = null):void {
      Logger.log("AxisTransmit: Disconnected from ", this.urlParsed.host + ":" + this.urlParsed.port);

      this.mic.removeEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleData);

      if ('playing' === this.currentState) {
        this.currentState = 'stopped';
        this.callAPI(EVENT_AUDIO_TRANSMIT_STOPPED);
      }
    }

    private function onMicSampleData(event:SampleDataEvent):void {
      if ('playing' !== this.currentState) {
        this.currentState = 'playing';
        this.callAPI(EVENT_AUDIO_TRANSMIT_STARTED);
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
          authState = 'none';
          return;
        }

        Logger.log('AxisTransmit: switching http-authorization from ' + authState + ' to ' + newAuthState);
        authState = newAuthState;
        this.close();
        this.connect();
        return;
      }
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
      if (null === mic) {
        ErrorManager.dispatchError(819);
        return;
      }

      _microphoneVolume = volume;
      mic.gain = volume;

      if (volume && savedUrl)
        start();
    }

    public function muteMicrophone():void {
      if (null === mic) {
        ErrorManager.dispatchError(819);
        return;
      }

      mic.gain = 0;
      stop();
    }

    public function unmuteMicrophone():void {
      if (null === mic) {
        ErrorManager.dispatchError(819);
        return;
      }

      if (mic.gain !== 0)
        return;

      mic.gain = this.microphoneVolume;
      start();
    }

    private function callAPI(eventName:String, data:Object = null):void {
      var functionName:String = "LocomoteMap['" + Player.locomoteID + "'].__playerEvent";
      if (data) {
        ExternalInterface.call(functionName, eventName, data);
      } else {
        ExternalInterface.call(functionName, eventName);
      }
    }
  }
}
