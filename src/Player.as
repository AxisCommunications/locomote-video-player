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
    private var config:Object = {
      'buffer': 1,
      'scaleUp': false
    };
    private var video:Video;
    private var audioTransmit:AxisTransmit = new AxisTransmit();
    private var meta:Object = {};
    private var client:IClient;
    private var ns:NetStream;
    private var urlParsed:Object;
    private var savedSpeakerVolume:Number;
    private var fullscreenAllowed:Boolean = true;

    public function Player() {
      var self:Player = this;

      Security.allowDomain("*");
      Security.allowInsecureDomain("*");

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
      ExternalInterface.addCallback("allowFullscreen", allowFullscreen);

      /* Audio Transmission API */
      ExternalInterface.addCallback("startAudioTransmit", startAudioTransmit);
      ExternalInterface.addCallback("stopAudioTransmit", stopAudioTransmit);

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

    public function fullscreen(event:MouseEvent):void {
      if (this.fullscreenAllowed)
        this.stage.displayState = (StageDisplayState.NORMAL === stage.displayState) ?
          StageDisplayState.FULL_SCREEN : StageDisplayState.NORMAL;
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

    public function play(iurl:String = null):void {
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
        this.callAPI('streamStarted');
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
      client.start();
    }

    public function pause():void {
      client.pause();
      this.callAPI('streamPaused');
    }

    public function resume():void {
      client.resume();
      this.callAPI('streamResumed');
    }

    public function stop():void {
      urlParsed = null;
      ns = null;
      client.stop();
      this.callAPI('streamStopped');
    }

    public function seek(timestamp:String):void {
      trace('seek, timestamp->' + timestamp);
    }

    public function playbackSpeed(speed:Number):void {
      trace('playbackSpeed, speed->' + speed);
    }

    public function streamStatus():Object {
      var status:Object = {
        'fps': Math.floor(this.ns.currentFPS + 0.5),
        'resolution': meta.width + 'x' + meta.height,
        'playbackSpeed': 1.0,
        'protocol': this.urlParsed.protocol,
        'audio': true,
        'video': true,
        'state': 'playing',
        'isSeekable': false,
        'isPlaybackSpeedChangeable': false,
        'streamURL': this.urlParsed.full
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
        'fullscreen': (StageDisplayState.FULL_SCREEN === stage.displayState)
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
      trace('stage added');
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
      if (urlParsed) {
        start();
      }
    }

    private function callAPI(eventName:String, data:Object = null):void {
      if (!ExternalInterface.available) {
        trace("ExternalInterface is not available!");
        return;
      }

      var functionName:String = "Locomote('" + ExternalInterface.objectID + "').__playerEvent";
      if (data) {
        ExternalInterface.call(functionName, eventName, data);
      } else {
        ExternalInterface.call(functionName, eventName);
      }
    }
  }
}
