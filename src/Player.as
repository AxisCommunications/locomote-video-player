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
  [SWF(backgroundColor="#000000")]

  public class Player extends Sprite {
    private var vid:Video;
    private var audioTransmit:AxisTransmit = new AxisTransmit();
    private var meta:Object = {};
    private static var ns:NetStream;

    public function Player() {

      Security.allowDomain("*");
      Security.allowInsecureDomain("*");

      ExternalInterface.marshallExceptions = true;

      /* Media player API */
      ExternalInterface.addCallback("play", play);

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

      vid.width  = Math.min(meta.width,  stagewidth);
      vid.height = Math.min(meta.height, stageheight);

      vid.x = 0;
      vid.y = 0;
      if (meta.width < stagewidth || meta.height < stageheight) {
        vid.x = (stagewidth - meta.width) / 2;
        vid.y = (stageheight - meta.height) / 2;
      }
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

      var rtspClient:RTSPClient = new RTSPClient(rtspHandle, urlParsed);
      rtspHandle.addEventListener('connected', function():void {
        rtspClient.start();
      });

      rtspHandle.connect();
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
