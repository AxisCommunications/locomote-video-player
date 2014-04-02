package {

  import flash.display.Sprite;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.events.Event;
  import flash.events.ErrorEvent;
  import flash.events.NetStatusEvent;
  import flash.events.ActivityEvent;
  import flash.events.ProgressEvent;
  import flash.events.StatusEvent;
  import flash.events.SampleDataEvent;
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

  public class Player extends Sprite {
    private var vid:Video;
    private var audioTransmit:AxisTransmit = new AxisTransmit();
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
      ns.client.onMetaData = function(item:Object):void {
        vid.width  = Math.min(item.width,  stage.stageWidth);
        vid.height = Math.min(item.height, stage.stageHeight);

        vid.x = 0;
        vid.y = 0;
        if (item.width < stage.stageWidth || item.height < stage.stageHeight) {
          vid.x = (stage.stageWidth - item.width) / 2;
          vid.y = (stage.stageHeight - item.height) / 2;
        }
      };

      ns.play(null);
      vid.attachNetStream(ns);
      addChild(vid);
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
        /* Regular RTSP */
        rtspHandle = new RTSPHandle(urlParsed);
      }

      var rtspClient:RTSPClient = new RTSPClient(rtspHandle, urlParsed);
      rtspHandle.onConnect(function():void {
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
