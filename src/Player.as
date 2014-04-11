package {

  import flash.display.Sprite;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.display.StageDisplayState;
  import flash.events.Event;
  import flash.events.ErrorEvent;
  import flash.events.NetStatusEvent;
  import flash.events.ActivityEvent;
  import flash.events.ProgressEvent;
  import flash.events.StatusEvent;
  import flash.events.SampleDataEvent;
  import flash.events.MouseEvent;
  import flash.external.ExternalInterface;
  import flash.media.Video;
  import flash.net.NetStream;
  import flash.net.NetConnection;
  import flash.net.Socket;
  import flash.system.Security;
  import flash.utils.getTimer;

  import com.axis.rtspclient.*;
  import com.axis.audioclient.AxisTransmit;
  import com.axis.http.url;

  [SWF(frameRate="60")]
  [SWF(backgroundColor="#efefef")]

  public class Player extends Sprite {
    private var config:Object = {
      'scaleUp' : false
    };
    private var vid:Video;
    private var audioTransmit:AxisTransmit = new AxisTransmit();
    private var meta:Object = {};
    private var client:RTSPClient;
    private static var ns:NetStream;

    public function Player() {

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

      var nc:NetConnection = new NetConnection();
      nc.connect(null);

      vid = new Video(stage.stageWidth, stage.stageHeight);

      ns = new NetStream(nc);
      ns.bufferTime = 1;
      ns.client = new Object();
      var self:Player = this;
      ns.client.onMetaData = function(item:Object):void {
        self.meta = item;
        videoResize();
      };

      this.stage.doubleClickEnabled = true;
      this.stage.addEventListener(MouseEvent.DOUBLE_CLICK, fullscreen);
      this.stage.addEventListener(Event.FULLSCREEN, function(event:Event):void {
        videoResize();
      });

      ns.play(null);
      vid.attachNetStream(ns);
      addChild(vid);
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

      vid.width = meta.width;
      vid.height = meta.height;
      if ((scale < 1.0) || (scale > 1.0 && true === config.scaleUp)) {
        trace('scaling video, scale:', scale.toFixed(2), ' (aspect ratio: ' +  (vid.width / vid.height).toFixed(2) + ')');
        vid.width = meta.width * scale;
        vid.height = meta.height * scale;
      }

      vid.x = (stagewidth - vid.width) / 2;
      vid.y = (stageheight - vid.height) / 2;
    }

    public function play(iurl:String = null):void
    {
      var urlParsed:Object = url.parse(iurl);

      var rtspHandle:IRTSPHandle = null;
      switch (urlParsed.protocol) {
      case 'rtsph':
        /* RTSP over HTTP */
        rtspHandle = new RTSPoverHTTPHandle(urlParsed);
        break;

      case 'rtsp':
        /* RTSP over TCP */
        rtspHandle = new RTSPoverTCPHandle(urlParsed);
      }

      client = new RTSPClient(rtspHandle, urlParsed);
      rtspHandle.addEventListener('connected', function():void {
        client.start();
      });

      rtspHandle.connect();
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

    public static function getNetStream():NetStream
    {
      return ns;
    }
  }
}
