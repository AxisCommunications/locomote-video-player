package {

  import com.axis.rtspclient.HTTPClient;
  import com.axis.audioclient.AxisTransmit;
  import flash.display.Sprite;
  import flash.display.LoaderInfo;
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

  [SWF(frameRate="60")]

  public class Player extends Sprite {
    private var jsEventCallbackName:String = "console.log";
    private var client:HTTPClient = new HTTPClient();
    private var transmit:Socket;

    private var vid:Video;
    private var audioTransmit:AxisTransmit = new AxisTransmit();
    private static var ns:NetStream;

    public function Player() {

      Security.allowDomain("*");
      Security.allowInsecureDomain("*");

      ExternalInterface.marshallExceptions = true;

      /* Media player API */
      ExternalInterface.addCallback("play", client.connect);
      ExternalInterface.addCallback("pause", client.disconnect);
      ExternalInterface.addCallback("stop", client.stop);

      /* Audio Transmission API */
      ExternalInterface.addCallback("audioTransmit", audioTransmitInterface);

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

    public function transmitAudio(url:String = null):void {
      audioTransmit.start(url)
    }

    public function audioTransmitInterface(state:Boolean, url:String = null):void {
      if (state) {
        audioTransmit.start(url);
      } else {
        audioTransmit.stop();
      }
    }

    private function onStageAdded(e:Event):void {
      client.addEventListener("connect", onConnect);
      client.addEventListener("disconnect", onDisconnect);

      client.sendLoadedEvent();
    }

    private function onDisconnect(e:Event):void {
      trace('onDisconnect', e);
    }

    private function onConnect(e:Event):void {
      trace('onConnect', e);
    }

    public static function getNetStream():NetStream
    {
      return ns;
    }
  }
}
