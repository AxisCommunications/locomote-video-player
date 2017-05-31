package {
  import com.axis.audioclient.AxisTransmit;
  import com.axis.ClientEvent;
  import com.axis.ErrorManager;
  import com.axis.http.url;
  import com.axis.httpclient.HTTPClient;
  import com.axis.IClient;
  import com.axis.Logger;
  import com.axis.mjpegclient.MJPEGClient;
  import com.axis.rtmpclient.RTMPClient;
  import com.axis.rtspclient.IRTSPHandle;
  import com.axis.rtspclient.RTSPClient;
  import com.axis.rtspclient.RTSPoverHTTPHandle;
  import com.axis.rtspclient.RTSPoverHTTPAPHandle;
  import com.axis.rtspclient.RTSPoverTCPHandle;

  import flash.display.LoaderInfo;
  import flash.display.Sprite;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageDisplayState;
  import flash.display.StageScaleMode;
  import flash.display.DisplayObject;
  import flash.display.InteractiveObject;
  import flash.events.Event;
  import flash.events.MouseEvent;
  import flash.external.ExternalInterface;
  import flash.media.Microphone;
  import flash.media.SoundMixer;
  import flash.media.SoundTransform;
  import flash.media.Video;
  import flash.net.NetStream;
  import flash.system.Security;
  import mx.utils.StringUtil;

  [SWF(frameRate="60")]
  [SWF(backgroundColor="#efefef")]

  public class Player extends Sprite {
    [Embed(source = "../VERSION", mimeType = "application/octet-stream")] private var Version:Class;

    public static var locomoteID:String = null;

    private static const EVENT_STREAM_STARTED:String  = "streamStarted";
    private static const EVENT_STREAM_PAUSED:String  = "streamPaused";
    private static const EVENT_STREAM_STOPPED:String  = "streamStopped";
    private static const EVENT_FULLSCREEN_ENTERED:String  = "fullscreenEntered";
    private static const EVENT_FULLSCREEN_EXITED:String  = "fullscreenExited";
    private static const EVENT_FRAME_READY:String  = "frameReady";

    public static var config:Object = {
      'buffer': 3,
      'keepAlive': 0,
      'connectionTimeout': 10,
      'scaleUp': false,
      'allowFullscreen': true,
      'debugLogger': false,
      'frameByFrame': false
    };

    private var audioTransmit:AxisTransmit = new AxisTransmit();
    private var meta:Object = {};
    private var client:IClient;
    private var urlParsed:Object;
    private var savedSpeakerVolume:Number;
    private var fullscreenAllowed:Boolean = true;
    private var currentState:String = "stopped";
    private var streamHasAudio:Boolean = false;
    private var streamHasVideo:Boolean = false;
    private var newPlaylistItem:Boolean = false;
    private var startOptions:Object = null;

    public function Player() {
      var self:Player = this;

      Security.allowDomain("*");
      Security.allowInsecureDomain("*");

      trace('Loaded Locomote, version ' + StringUtil.trim(new Version().toString()));

      if (ExternalInterface.available) {
          setupAPICallbacks();
      } else {
        trace("External interface is not available for this container.");
      }

      /* Set default speaker volume */
      this.speakerVolume(50);

      /* Stage setup */
      this.stage.align = StageAlign.TOP_LEFT;
      this.stage.scaleMode = StageScaleMode.NO_SCALE;
      addEventListener(Event.ADDED_TO_STAGE, onStageAdded);

      /* Fullscreen support setup */
      this.stage.doubleClickEnabled = true;
      this.stage.addEventListener(MouseEvent.DOUBLE_CLICK, fullscreen);
      this.stage.addEventListener(Event.FULLSCREEN, function(event:Event):void {
        (StageDisplayState.NORMAL === stage.displayState) ? callAPI(EVENT_FULLSCREEN_EXITED) : callAPI(EVENT_FULLSCREEN_ENTERED);
      });
      this.stage.addEventListener(Event.RESIZE, function(event:Event):void {
        videoResize();
      });

      this.setConfig(Player.config);
    }

    /**
     * Registers the appropriate API functions with the container, so that
     * they can be called, and triggers the apiReady event
     * which tells the container that the Player is ready to receive API calls.
     */
    public function setupAPICallbacks():void {
      ExternalInterface.marshallExceptions = true;

      /* Media player API */
      ExternalInterface.addCallback("play", play);
      ExternalInterface.addCallback("pause", pause);
      ExternalInterface.addCallback("resume", resume);
      ExternalInterface.addCallback("stop", stop);
      ExternalInterface.addCallback("seek", seek);
      ExternalInterface.addCallback("playFrames", playFrames);
      ExternalInterface.addCallback("streamStatus", streamStatus);
      ExternalInterface.addCallback("playerStatus", playerStatus);
      ExternalInterface.addCallback("speakerVolume", speakerVolume);
      ExternalInterface.addCallback("muteSpeaker", muteSpeaker);
      ExternalInterface.addCallback("unmuteSpeaker", unmuteSpeaker);
      ExternalInterface.addCallback("microphoneVolume", microphoneVolume);
      ExternalInterface.addCallback("muteMicrophone", muteMicrophone);
      ExternalInterface.addCallback("unmuteMicrophone", unmuteMicrophone);
      ExternalInterface.addCallback("setConfig", setConfig);
      ExternalInterface.addCallback("loadPolicyFile", loadPolicyFile);

      /* Audio Transmission API */
      ExternalInterface.addCallback("startAudioTransmit", startAudioTransmit);
      ExternalInterface.addCallback("stopAudioTransmit", stopAudioTransmit);
    }

    public function fullscreen(event:MouseEvent):void {
      if (config.allowFullscreen) {
        this.stage.displayState = (StageDisplayState.NORMAL === stage.displayState) ?
          StageDisplayState.FULL_SCREEN : StageDisplayState.NORMAL;
      }
    }

    public function videoResize():void {
      if (!this.client) {
        return;
      }

      var stagewidth:uint = (StageDisplayState.NORMAL === stage.displayState) ?
        stage.stageWidth : stage.fullScreenWidth;
      var stageheight:uint = (StageDisplayState.NORMAL === stage.displayState) ?
        stage.stageHeight : stage.fullScreenHeight;

      var video:DisplayObject = this.client.getDisplayObject();

      var scale:Number = ((stagewidth / meta.width) > (stageheight / meta.height)) ?
        (stageheight / meta.height) : (stagewidth / meta.width);

      video.width = meta.width;
      video.height = meta.height;
      if ((scale < 1.0) || (scale > 1.0 && true === config.scaleUp)) {
        Logger.log('scaling video, scale:' + scale.toFixed(2) + ' (aspect ratio: ' +  (video.width / video.height).toFixed(2) + ')');
        video.width = meta.width * scale;
        video.height = meta.height * scale;
      }

      video.x = (stagewidth - video.width) / 2;
      video.y = (stageheight - video.height) / 2;
    }

    public function setConfig(iconfig:Object):void {
      if (iconfig.buffer !== undefined) {
        if (this.client) {
          if (false === this.client.setBuffer(config.buffer)) {
            ErrorManager.dispatchError(830);
          } else {
            config.buffer = iconfig.buffer;
          }
        } else {
            config.buffer = iconfig.buffer;
        }
      }

       if (iconfig.keepAlive !== undefined) {
         if (this.client && !this.client.setKeepAlive(config.keepAlive)) {
           ErrorManager.dispatchError(834);
         } else {
           config.keepAlive = iconfig.keepAlive;
         }
      }

      if (iconfig.frameByFrame !== undefined) {
        if (this.client) {
          if (false === this.client.setFrameByFrame(iconfig.frameByFrame)) {
            ErrorManager.dispatchError(832);
          } else {
            config.frameByFrame = iconfig.frameByFrame;
          }
        } else {
          config.frameByFrame = iconfig.frameByFrame;
        }
      }

      if (iconfig.scaleUp !== undefined) {
        var scaleUpChanged:Boolean = (config.scaleUp !== iconfig.scaleUp);
        config.scaleUp = iconfig.scaleUp;
        if (scaleUpChanged && this.client)
          this.videoResize();
      }

      if (iconfig.allowFullscreen !== undefined) {
        config.allowFullscreen = iconfig.allowFullscreen;

        if (!config.allowFullscreen)
          this.stage.displayState = StageDisplayState.NORMAL;
      }

      if (iconfig.debugLogger !== undefined) {
        config.debugLogger = iconfig.debugLogger;
      }

      if (iconfig.connectionTimeout !== undefined) {
        config.connectionTimeout = iconfig.connectionTimeout;
      }
    }

    public function loadPolicyFile(url:String):String {
      Security.loadPolicyFile(url);
      return "ok";
    }

    public function play(param:* = null, options:Object = null):void {
      this.streamHasAudio = false;
      this.streamHasVideo = false;

      if (param is String) {
        urlParsed = url.parse(String(param));
      } else {
        urlParsed = url.parse(param.url);
        urlParsed.connect = param.url;
        urlParsed.streamName = param.streamName;
      }

      this.newPlaylistItem = true;
      this.startOptions = options;

      if (client) {
        /* Stop the client, and 'onStopped' will start the new stream. */
        client.stop();
        return;
      }

      start();
    }

    private function start():void {
      switch (urlParsed.protocol) {
      case 'rtsph':
        /* RTSP over HTTP */
        client = new RTSPClient(urlParsed, new RTSPoverHTTPHandle(this.startOptions && this.startOptions.httpUrl ? url.parse(this.startOptions.httpUrl) : urlParsed, false));
        break;

      case 'rtsphs':
        /* RTSP over HTTPS */
        client = new RTSPClient(urlParsed, new RTSPoverHTTPHandle(this.startOptions && this.startOptions.httpUrl ? url.parse(this.startOptions.httpUrl) : urlParsed, true));
        break;

      case 'rtsphnap':
        /* RTSP over HTTP via non-secure Axis Proxy */
        client = new RTSPClient(urlParsed, new RTSPoverHTTPAPHandle(urlParsed, false));
        break;

      case 'rtsphap':
        /* RTSP over HTTP via Axis Proxy */
        client = new RTSPClient(urlParsed, new RTSPoverHTTPAPHandle(urlParsed, true));
        break;

      case 'rtsp':
        /* RTSP over TCP */
        client = new RTSPClient(urlParsed, new RTSPoverTCPHandle(urlParsed));
        break;

      case 'http':
      case 'https':
        /* Progressive download over HTTP */
        client = new HTTPClient(urlParsed);
        break;

      case 'httpm':
        /* Progressive mjpg download over HTTP (x-mixed-replace) */
        client = new MJPEGClient(urlParsed);
        break;

      case 'rtmp':
      case 'rtmps':
      case 'rtmpt':
        /* RTMP */
        client = new RTMPClient(urlParsed);
        break;

      default:
        ErrorManager.dispatchError(811, [urlParsed.protocol])
        return;
      }

      addChild(this.client.getDisplayObject());

      client.addEventListener(ClientEvent.STOPPED, onStopped);
      client.addEventListener(ClientEvent.START_PLAY, onStartPlay);
      client.addEventListener(ClientEvent.PAUSED, onPaused);
      client.addEventListener(ClientEvent.META, onMeta);
      client.addEventListener(ClientEvent.FRAME, onFrame);
      client.start(this.startOptions);
      this.newPlaylistItem = false;
    }

    public function seek(position:String):void {
      if (!client || !client.seek(Number(position))) {
        ErrorManager.dispatchError(828);
      }
    }

    public function playFrames(timestamp:Number):void {
      client && client.playFrames(timestamp);
    }

    public function pause():void {
      if (!client || !client.pause()) {
        ErrorManager.dispatchError(808);
      }
    }

    public function resume():void {
      if (!client || !client.resume()) {
        ErrorManager.dispatchError(809);
      }
    }

    public function stop():void {
      if (!client || !client.stop()) {
        ErrorManager.dispatchError(810);
        return;
      }

      this.currentState = "stopped";
      this.streamHasAudio = false;
      this.streamHasVideo = false;
    }

    public function onMeta(event:ClientEvent):void {
      this.meta = event.data;
      this.videoResize();
    }

    public function streamStatus():Object {
      var status:Object = {
        'fps': (this.client) ? this.client.currentFPS() : null,
        'resolution': (this.client) ? { width: meta.width, height: meta.height } : null,
        'playbackSpeed': (this.client) ? 1.0 : null,
        'audio': (this.client) ? this.client.hasAudio() : null,
        'protocol': (this.urlParsed) ? this.urlParsed.protocol : null,
        'state': this.currentState,
        'streamURL': (this.urlParsed) ? this.urlParsed.full : null,
        'duration': meta.duration ? meta.duration : null,
        'currentTime': (this.client) ? this.client.getCurrentTime() : -1,
        'bufferedTime': (this.client) ? this.client.bufferedTime() : -1
      };

      return status;
    }

    public function playerStatus():Object {
      var mic:Microphone = Microphone.getMicrophone();

      var status:Object = {
        'version': StringUtil.trim(new Version().toString()),
        'microphoneVolume': audioTransmit.microphoneVolume,
        'speakerVolume': this.savedSpeakerVolume,
        'microphoneMuted': (mic.gain === 0),
        'speakerMuted': (flash.media.SoundMixer.soundTransform.volume === 0),
        'fullscreen': (StageDisplayState.FULL_SCREEN === stage.displayState),
        'buffer': (client === null) ? 0 : Player.config.buffer
      };

      return status;
    }

    public function speakerVolume(volume:Number):void {
      this.savedSpeakerVolume = volume;
      var transform:SoundTransform = new SoundTransform(volume / 100.0);
      flash.media.SoundMixer.soundTransform = transform;
    }

    public function muteSpeaker():void {
      var transform:SoundTransform = new SoundTransform(0);
      flash.media.SoundMixer.soundTransform = transform;
    }

    public function unmuteSpeaker():void {
      if (flash.media.SoundMixer.soundTransform.volume !== 0)
        return;

      var transform:SoundTransform = new SoundTransform(this.savedSpeakerVolume / 100.0);
      flash.media.SoundMixer.soundTransform = transform;
    }

    public function microphoneVolume(volume:Number):void {
      audioTransmit.microphoneVolume = volume;
    }

    public function muteMicrophone():void {
      audioTransmit.muteMicrophone();
    }

    public function unmuteMicrophone():void {
      audioTransmit.unmuteMicrophone();
    }

    public function startAudioTransmit(url:String = null, type:String = 'axis'):void {
      if (type === 'axis') {
        audioTransmit.start(url);
      } else {
        ErrorManager.dispatchError(812);
      }
    }

    public function stopAudioTransmit():void {
      audioTransmit.stop();
    }

    public function allowFullscreen(state:Boolean):void {
      this.fullscreenAllowed = state;

      if (!state)
        this.stage.displayState = StageDisplayState.NORMAL;
    }

    private function onStageAdded(e:Event):void {
      Player.locomoteID = LoaderInfo(this.root.loaderInfo).parameters.locomoteID.toString();
      ExternalInterface.call("LocomoteMap['" + Player.locomoteID + "'].__swfReady");
    }

    private function onStartPlay(event:ClientEvent):void {
      this.currentState = "playing";
      this.callAPI(EVENT_STREAM_STARTED);
    }

    private function onPaused(event:ClientEvent):void {
      this.currentState = "paused";
      this.callAPI(EVENT_STREAM_PAUSED, event.data);
    }

    private function onStopped(event:ClientEvent):void {
      this.removeChild(this.client.getDisplayObject());
      this.client.removeEventListener(ClientEvent.STOPPED, onStopped);
      this.client.removeEventListener(ClientEvent.START_PLAY, onStartPlay);
      this.client.removeEventListener(ClientEvent.PAUSED, onPaused);
      this.client.removeEventListener(ClientEvent.META, onMeta);
      this.client.removeEventListener(ClientEvent.FRAME, onFrame);
      this.client = null;
      this.callAPI(EVENT_STREAM_STOPPED);

      /* If a new `play` has been queued, fire it */
      if (this.newPlaylistItem) {
        start();
      }
    }

    private function onFrame(event:ClientEvent):void {
      this.callAPI(EVENT_FRAME_READY, { timestamp: event.data });
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
