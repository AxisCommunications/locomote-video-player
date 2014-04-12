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
  import flash.net.NetStream;
  import flash.net.NetConnection;
  import flash.system.Security;

  import com.axis.http.url;
  import com.axis.IClient;

  import com.axis.rtspclient.RTSPClient;
  import com.axis.rtspclient.IRTSPHandle;
  import com.axis.rtspclient.RTSPoverTCPHandle;
  import com.axis.rtspclient.RTSPoverHTTPHandle;

  import com.axis.httpclient.HTTPClient;

  import com.axis.audioclient.AxisTransmit;

  [SWF(frameRate="60")]
  [SWF(backgroundColor="#efefef")]

  public class Player extends Sprite {
    private var config:Object = {
      'buffer' : 0,
      'scaleUp' : false
    };
    private var vid:Video;
    private var audioTransmit:AxisTransmit = new AxisTransmit();
    private var meta:Object = {};
    private var client:IClient;
    private var ns:NetStream;

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

      var nc:NetConnection = new NetConnection();
      nc.connect(null);

      ns = new NetStream(nc);
      ns.bufferTime = config.buffer;
      ns.client = new Object();
      ns.client.onMetaData = function(item:Object):void {
        self.meta = item;
        videoResize();
      };

      vid = new Video(stage.stageWidth, stage.stageHeight);
      vid.attachNetStream(ns);
      addChild(vid);

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

      switch (urlParsed.protocol) {
      case 'rtsph':
        /* RTSP over HTTP */
        client = new RTSPClient(this.ns, urlParsed, new RTSPoverHTTPHandle(urlParsed));
        break;

      case 'rtsp':
        /* RTSP over TCP */
        client = new RTSPClient(this.ns, urlParsed, new RTSPoverTCPHandle(urlParsed));
        break;

      case 'http':
        client = new HTTPClient(this.ns, urlParsed);
        break;

      default:
        trace('Unknown streaming protocol:', urlParsed.protocol)
        return;
      }

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
  }
}
