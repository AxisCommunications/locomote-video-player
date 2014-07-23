package {
  import com.axis.ClientEvent;
  import com.axis.IClient;
  import com.axis.audioclient.AxisTransmit;
  import com.axis.http.url;
  import com.axis.httpclient.HTTPClient;
  import com.axis.rtmpclient.RTMPClient;
  import com.axis.rtspclient.IRTSPHandle;
  import com.axis.rtspclient.RTSPClient;
  import com.axis.rtspclient.RTSPoverHTTPHandle;
  import com.axis.rtspclient.RTSPoverTCPHandle;

  import flash.display.Sprite;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageDisplayState;
  import flash.display.StageScaleMode;
  import flash.events.Event;
  import flash.events.MouseEvent;
  import flash.external.ExternalInterface;
  import flash.media.Microphone;
  import flash.media.SoundMixer;
  import flash.media.SoundTransform;
  import flash.media.Video;
  import flash.net.NetStream;
  import flash.system.Security;

  [SWF(frameRate="60")]
  [SWF(backgroundColor="#efefef")]

  public class Player extends Sprite {
    private static const EVENT_STREAM_STARTED:String  = "streamStarted";
    private static const EVENT_STREAM_PAUSED:String  = "streamPaused";
    private static const EVENT_STREAM_STOPPED:String  = "streamStopped";
    private static const EVENT_FULLSCREEN_ENTERED:String  = "fullscreenEntered";
    private static const EVENT_FULLSCREEN_EXITED:String  = "fullscreenExited";

    private var config:Object = {
      'buffer': 1,
      'scaleUp': false,
      'allowFullscreen': true
    };
    private var video:Video;
    private var audioTransmit:AxisTransmit = new AxisTransmit();
    private var meta:Object = {};
    private var client:IClient;
    private var ns:NetStream;
    private var urlParsed:Object;
    private var savedSpeakerVolume:Number;
    private var fullscreenAllowed:Boolean = true;
    private var currentState:String = "stopped";
    private var streamHasAudio:Boolean = false;
    private var streamHasVideo:Boolean = false;

    public function Player() {
      var self:Player = this;

      Security.allowDomain("*");
      Security.allowInsecureDomain("*");

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

      /* Video object setup */
      video = new Video(stage.stageWidth, stage.stageHeight);
      addChild(video);

      /* Fullscreen support setup */
      this.stage.doubleClickEnabled = true;
      this.stage.addEventListener(MouseEvent.DOUBLE_CLICK, fullscreen);
      this.stage.addEventListener(Event.FULLSCREEN, function(event:Event):void {
        videoResize();
      });
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
      ExternalInterface.addCallback("playbackSpeed", playbackSpeed);
      ExternalInterface.addCallback("streamStatus", streamStatus);
      ExternalInterface.addCallback("playerStatus", playerStatus);
      ExternalInterface.addCallback("speakerVolume", speakerVolume);
      ExternalInterface.addCallback("muteSpeaker", muteSpeaker);
      ExternalInterface.addCallback("unmuteSpeaker", unmuteSpeaker);
      ExternalInterface.addCallback("microphoneVolume", microphoneVolume);
      ExternalInterface.addCallback("muteMicrophone", muteMicrophone);
      ExternalInterface.addCallback("unmuteMicrophone", unmuteMicrophone);
      ExternalInterface.addCallback("setConfig", setConfig);

      /* Audio Transmission API */
      ExternalInterface.addCallback("startAudioTransmit", startAudioTransmit);
      ExternalInterface.addCallback("stopAudioTransmit", stopAudioTransmit);
    }

    public function fullscreen(event:MouseEvent):void {
      if (config.allowFullscreen) {
        this.stage.displayState = (StageDisplayState.NORMAL === stage.displayState) ?
          StageDisplayState.FULL_SCREEN : StageDisplayState.NORMAL;
          (StageDisplayState.NORMAL === stage.displayState) ? this.callAPI(EVENT_FULLSCREEN_EXITED) : this.callAPI(EVENT_FULLSCREEN_ENTERED);
      }
    }

    public function videoResize():void {
      var stagewidth:uint = (StageDisplayState.NORMAL === stage.displayState) ?
        stage.stageWidth : stage.fullScreenWidth;
      var stageheight:uint = (StageDisplayState.NORMAL === stage.displayState) ?
        stage.stageHeight : stage.fullScreenHeight;

      var scale:Number = ((stagewidth / meta.width) > (stageheight / meta.height)) ?
        (stageheight / meta.height) : (stagewidth / meta.width);

      video.width = meta.width;
      video.height = meta.height;
      if ((scale < 1.0) || (scale > 1.0 && true === config.scaleUp)) {
        trace('scaling video, scale:', scale.toFixed(2), ' (aspect ratio: ' +  (video.width / video.height).toFixed(2) + ')');
        video.width = meta.width * scale;
        video.height = meta.height * scale;
      }

      video.x = (stagewidth - video.width) / 2;
      video.y = (stageheight - video.height) / 2;
    }

    public function setConfig(iconfig:Object):void {
      if (iconfig.buffer !== undefined) {
        config.buffer = iconfig.buffer;
        this.ns.bufferTime = config.buffer;
        this.client.forceBuffering();
      }

      if (iconfig.scaleUp !== undefined) {
        var scaleUpChanged:Boolean = (config.scaleUp !== iconfig.scaleUp);
        config.scaleUp = iconfig.scaleUp;
        if (scaleUpChanged)
          this.videoResize();
      }

      if (iconfig.allowFullscreen !== undefined) {
        config.allowFullscreen = iconfig.allowFullscreen;

        if (!config.allowFullscreen)
          this.stage.displayState = StageDisplayState.NORMAL;
      }
    }

    public function play(iurl:String = null):void {
      this.streamHasAudio = false;
      this.streamHasVideo = false;
      if (client) {
        urlParsed = url.parse(iurl);
        /* Stop the client, and 'onStopped' will start the new stream. */
        client.stop();
        return;
      }

      urlParsed = url.parse(iurl);
      start();
    }

    private function start():void {
      switch (urlParsed.protocol) {
      case 'rtsph':
        /* RTSP over HTTP */
        client = new RTSPClient(this.video, urlParsed, new RTSPoverHTTPHandle(urlParsed));
        break;

      case 'rtsp':
        /* RTSP over TCP */
        client = new RTSPClient(this.video, urlParsed, new RTSPoverTCPHandle(urlParsed));
        break;

      case 'http':
        /* Progressive download over HTTP */
        client = new HTTPClient(this.video, urlParsed);
        break;

      case 'rtmp':
        /* RTMP */
        client = new RTMPClient(this.video, urlParsed);
        break;

      default:
        trace('Unknown streaming protocol:', urlParsed.protocol)
        return;
      }

      client.addEventListener(ClientEvent.NETSTREAM_CREATED, onNetStreamCreated);
      client.addEventListener(ClientEvent.STOPPED, onStopped);
      client.addEventListener(ClientEvent.START_PLAY, onStartPlay);
      client.start();
    }

    public function pause():void {
      client.pause();
      this.callAPI(EVENT_STREAM_PAUSED);
      this.currentState = "paused";
    }

    public function resume():void {
      client.resume();
    }

    public function stop():void {
      urlParsed = null;
      ns = null;
      client.stop();
      this.currentState = "stopped";
      this.streamHasAudio = false;
      this.streamHasVideo = false;
    }

    public function seek(timestamp:String):void {
      trace('seek, timestamp->' + timestamp);
    }

    public function playbackSpeed(speed:Number):void {
      trace('playbackSpeed, speed->' + speed);
    }

    public function streamStatus():Object {
      if (this.currentState === 'playing') {
        this.streamHasAudio = (this.streamHasAudio || this.ns.info.audioBufferByteLength);
        this.streamHasVideo = (this.streamHasVideo || this.ns.info.videoBufferByteLength);
      }
      var status:Object = {
        'fps': (this.ns) ? Math.floor(this.ns.currentFPS + 0.5) : null,
        'resolution': (this.ns) ? { width: meta.width, height: meta.height } : null,
        'playbackSpeed': (this.ns) ? 1.0 : null,
        'protocol': (this.urlParsed) ? this.urlParsed.protocol: null,
        'audio': (this.ns) ? this.streamHasAudio : null,
        'video': (this.ns) ? this.streamHasVideo : null,
        'state': this.currentState,
        'isSeekable': false,
        'isPlaybackSpeedChangeable': false,
        'streamURL': (this.urlParsed) ? this.urlParsed.full : null
      };

      return status;
    }

    public function playerStatus():Object {
      var mic:Microphone = Microphone.getMicrophone();

      var status:Object = {
        'microphoneVolume': audioTransmit.microphoneVolume,
        'speakerVolume': this.savedSpeakerVolume,
        'microphoneMuted': (mic.gain === 0),
        'speakerMuted': (flash.media.SoundMixer.soundTransform.volume === 0),
        'fullscreen': (StageDisplayState.FULL_SCREEN === stage.displayState),
        'buffer': this.ns.bufferTime
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
        trace("unsupported type");
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
      ExternalInterface.call("Locomote('" + ExternalInterface.objectID + "').__swfReady");
    }

    public function onMetaData(item:Object):void {
      this.meta = item;
      this.videoResize();
    }

    public function onNetStreamCreated(ev:ClientEvent):void {
      this.ns = ev.data.ns;
      ev.data.ns.bufferTime = config.buffer;
      ev.data.ns.client = this;
    }

    private function onStopped(ev:ClientEvent):void {
      video.clear();
      client = null;
      this.callAPI(EVENT_STREAM_STOPPED);
      if (urlParsed) {
        start();
      }
    }

    private function onStartPlay(ev:ClientEvent):void {
      this.currentState = "playing";
      this.callAPI(EVENT_STREAM_STARTED);
    }

    public function onPlayStatus(ev:Object):void {
      this.currentState = "stopped";
    }

    private function callAPI(eventName:String, data:Object = null):void {
      var functionName:String = "Locomote('" + ExternalInterface.objectID + "').__playerEvent";
      if (data) {
        ExternalInterface.call(functionName, eventName, data);
      } else {
        ExternalInterface.call(functionName, eventName);
      }
    }
  }
}
