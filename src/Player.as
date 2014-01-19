package {

  import com.axis.rtspclient.HTTPClient;
  import flash.display.Sprite;
  import flash.display.LoaderInfo;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.events.Event;
  import flash.events.NetStatusEvent;
  import flash.external.ExternalInterface;
  import flash.media.Video;
  import flash.net.NetStream;
  import flash.net.NetStreamAppendBytesAction;
  import flash.utils.ByteArray;
  import flash.net.NetConnection;

  import flash.events.ProgressEvent;
  import flash.net.Socket;

  import com.axis.rtspclient.ByteArrayUtils;

  [SWF(frameRate="60")]

  public class Player extends Sprite {
    private var jsEventCallbackName:String = "console.log";
    private var client:HTTPClient = new HTTPClient();

    private var vid:Video;
    private static var ns:NetStream;

    public function Player() {

      this.stage.align = StageAlign.TOP_LEFT;
      this.stage.scaleMode = StageScaleMode.NO_SCALE;
      addEventListener(Event.ADDED_TO_STAGE, onStageAdded);

      var nc:NetConnection = new NetConnection();
      nc.connect(null);

      vid = new Video(640,480);

      ns = new NetStream(nc);
      ns.play(null);
      vid.attachNetStream(ns);

      addChild(vid);
    }

    private var processedHeaders:Boolean = false;
    private var flvBytes:ByteArray = new ByteArray();
    private function onStageAdded(e:Event):void {
      client.addEventListener("connect", onConnect);
      client.addEventListener("disconnect", onDisconnect);

      client.setJsEventCallbackName(jsEventCallbackName);

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
