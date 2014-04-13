package {

  import flash.display.Sprite;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.display.StageDisplayState;
  import flash.events.Event;
  import flash.events.MouseEvent;
  import flash.external.ExternalInterface;
  import flash.media.Video;
  import flash.system.Security;

  import com.axis.http.url;
  import com.axis.IClient;
  import com.axis.ClientEvent;

  import com.axis.rtspclient.RTSPClient;
  import com.axis.rtspclient.IRTSPHandle;
  import com.axis.rtspclient.RTSPoverTCPHandle;
  import com.axis.rtspclient.RTSPoverHTTPHandle;
  import com.axis.httpclient.HTTPClient;
  import com.axis.rtmpclient.RTMPClient;

  import com.axis.audioclient.AxisTransmit;

  [SWF(frameRate="60")]
  [SWF(backgroundColor="#efefef")]

  public class Player extends Sprite {
    private var config:Object = {
      'buffer' : 1,
      'scaleUp' : false
    };
    private var video:Video;
    private var audioTransmit:AxisTransmit = new AxisTransmit();
    private var meta:Object = {};
    private var client:IClient;

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

      /* Audio Transmission API */
      ExternalInterface.addCallback("startAudioTransmit", audioTransmitStartInterface);
      ExternalInterface.addCallback("stopAudioTransmit", audioTransmitStopInterface);

      this.stage.align = StageAlign.TOP_LEFT;
      this.stage.scaleMode = StageScaleMode.NO_SCALE;
      addEventListener(Event.ADDED_TO_STAGE, onStageAdded);

      video = new Video(stage.stageWidth, stage.stageHeight);
      addChild(video);

      this.stage.doubleClickEnabled = true;
      this.stage.addEventListener(MouseEvent.DOUBLE_CLICK, fullscreen);
      this.stage.addEventListener(Event.FULLSCREEN, function(event:Event):void {
        videoResize();
      });
    }

    public function fullscreen(event:MouseEvent):void
    {
      this.stage.displayState = (StageDisplayState.NORMAL === stage.displayState) ?
        StageDisplayState.FULL_SCREEN : StageDisplayState.NORMAL;
    }

    public function videoResize():void
    {
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

    public function play(iurl:String = null):void
    {
      var urlParsed:Object = url.parse(iurl);

      if (client) {
        stop();
      }

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
      client.start();
    }

    public function pause():void
    {
      client.pause();
    }

    public function resume():void
    {
      client.resume();
    }

    public function stop():void
    {
      client.stop();
      video.clear();
    }

    public function audioTransmitStopInterface():void {
      audioTransmit.stop();
    }

    public function audioTransmitStartInterface(url:String = null):void {
      audioTransmit.start(url);
    }

    private function onStageAdded(e:Event):void {
      trace('stage added');
    }

    public function onMetaData(item:Object):void
    {
      this.meta = item;
      this.videoResize();
    }

    public function onNetStreamCreated(ev:ClientEvent):void
    {
      ev.data.ns.bufferTime = config.bufferTime;
      ev.data.ns.client = this;
    }
  }
}
