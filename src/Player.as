package {
  import com.axis.ClientEvent;
  import com.axis.ErrorManager;
  import com.axis.IClient;
  import com.axis.audioclient.AxisTransmit;
  import com.axis.http.url;
  import com.axis.httpclient.HTTPClient;
  import com.axis.rtmpclient.RTMPClient;
  import com.axis.rtspclient.IRTSPHandle;
  import com.axis.rtspclient.RTSPClient;
  import com.axis.rtspclient.RTSPoverHTTPHandle;
  import com.axis.rtspclient.RTSPoverTCPHandle;

  import flash.display.LoaderInfo;
  import flash.display.Sprite;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageDisplayState;
  import flash.display.StageScaleMode;
  import flash.events.AsyncErrorEvent;
  import flash.events.DRMErrorEvent;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.events.MouseEvent;
  import flash.events.NetStatusEvent;
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
    public static var locomoteID:String = null;

    private static const EVENT_STREAM_STARTED:String  = "streamStarted";
    private static const EVENT_STREAM_PAUSED:String  = "streamPaused";
    private static const EVENT_STREAM_STOPPED:String  = "streamStopped";
    private static const EVENT_STREAM_ENDED:String  = "streamEnded";
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
        (StageDisplayState.NORMAL === stage.displayState) ? callAPI(EVENT_FULLSCREEN_EXITED) : callAPI(EVENT_FULLSCREEN_ENTERED);
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
        if (this.ns) {
          this.ns.bufferTime = config.buffer;
          this.client.forceBuffering();
        }
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
      case 'rtmps':
      case 'rtmpt':
        /* RTMP */
        client = new RTMPClient(this.video, urlParsed);
        break;

      default:
        ErrorManager.dispatchError(814, [urlParsed.protocol])
        return;
      }

      client.addEventListener(ClientEvent.NETSTREAM_CREATED, onNetStreamCreated);
      client.addEventListener(ClientEvent.STOPPED, onStopped);
      client.addEventListener(ClientEvent.START_PLAY, onStartPlay);
      client.addEventListener(ClientEvent.PAUSED, onPaused);
      client.start();
    }

    public function pause():void {
      if (ns === null) {
        ErrorManager.dispatchError(811);
        return;
      }
      client.pause();
    }

    public function resume():void {
      if (ns === null) {
        ErrorManager.dispatchError(812);
        return;
      }
      client.resume();
    }

    public function stop():void {
      if (client === null) {
        ErrorManager.dispatchError(813);
        return;
      }
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
        'protocol': (this.urlParsed) ? this.urlParsed.protocol : null,
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
        'buffer': (ns === null) ? 0 : this.ns.bufferTime
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
        ErrorManager.dispatchError(815);
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
      ExternalInterface.call("Locomote('" + Player.locomoteID + "').__swfReady");
    }

    public function onMetaData(item:Object):void {
      this.meta = item;
      this.videoResize();
    }

    public function onNetStreamCreated(ev:ClientEvent):void {
      this.ns = ev.data.ns;
      ev.data.ns.bufferTime = config.buffer;
      ev.data.ns.client = this;
      this.ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
      this.ns.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
      this.ns.addEventListener(DRMErrorEvent.DRM_ERROR, onDRMError);
      this.ns.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
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
      video.clear();
      client = null;
      this.callAPI(EVENT_STREAM_STOPPED);
      if (urlParsed) {
        start();
      }
    }

    public function onPlayStatus(event:Object):void {
      if ('NetStream.Play.Complete' === event.code) {
        video.clear();
        client = null;
        this.currentState = "stopped";
        this.callAPI(EVENT_STREAM_STOPPED);
        this.callAPI(EVENT_STREAM_ENDED);
      }
    }

    private function onNetStatus(event:NetStatusEvent):void {
      if (event.info.status === 'error') {
        var errorCode:int = 0;
        switch (event.info.code) {
        case 'NetConnection.Call.BadVersion':
          errorCode = 700;
          break;
        case 'NetConnection.Call.Failed':
          errorCode = 701;
          break;
        case 'NetConnection.Call.Prohibited':
          errorCode = 702;
          break;
        case 'NetConnection.Connect.AppShutdown':
          errorCode = 703;
          break;
        case 'NetConnection.Connect.Failed':
          errorCode = 704;
          break;
        case 'NetConnection.Connect.InvalidApp':
          errorCode = 705;
          break;
        case 'NetConnection.Connect.Rejected':
          errorCode = 706;
          break;
        case 'NetGroup.Connect.Failed':
          errorCode = 707;
          break;
        case 'NetGroup.Connect.Rejected':
          errorCode = 708;
          break;
        case 'NetStream.Connect.Failed':
          errorCode = 709;
          break;
        case 'NetStream.Connect.Rejected':
          errorCode = 710;
          break;
        case 'NetStream.Failed':
          errorCode = 711;
          break;
        case 'NetStream.Play.Failed':
          errorCode = 712;
          break;
        case 'NetStream.Play.FileStructureInvalid':
          errorCode = 713;
          break;
        case 'NetStream.Play.InsufficientBW':
          errorCode = 714;
          break;
        case 'NetStream.Play.StreamNotFound':
          errorCode = 715;
          break;
        case 'NetStream.Publish.BadName':
          errorCode = 716;
          break;
        case 'NetStream.Record.Failed':
          errorCode = 717;
          break;
        case 'NetStream.Record.NoAccess':
          errorCode = 718;
          break;
        case 'NetStream.Seek.Failed':
          errorCode = 719;
          break;
        case 'NetStream.Seek.InvalidTime':
          errorCode = 720;
          break;
        case 'SharedObject.BadPersistence':
          errorCode = 721;
          break;
        case 'SharedObject.Flush.Failed':
          errorCode = 722;
          break;
        case 'SharedObject.UriMismatch':
          errorCode = 723;
          break;

        default:
          ErrorManager.dispatchError(724, [event.info.code]);
          return;
        }

        if (errorCode) {
          ErrorManager.dispatchError(errorCode);
        }
      }
    }

    private function onAsyncError(event:AsyncErrorEvent):void {
      ErrorManager.dispatchError(725);
    }

    private function onDRMError(event:DRMErrorEvent):void {
      ErrorManager.dispatchError(726, [event.errorID, event.subErrorID]);
    }

    private function onIOError(event:IOErrorEvent):void {
      ErrorManager.dispatchError(727, [event.text]);
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
