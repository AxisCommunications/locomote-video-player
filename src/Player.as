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

      var customClient:Object = new Object();

      customClient.onImageData = function (imageData:Object):void {
        ExternalInterface.call(jsEventCallbackName,
            "imageData length:");
      }

      customClient.onMetaData = function (item:Object):void {
        ExternalInterface.call(jsEventCallbackName, JSON.stringify(item));
      }

      this.stage.align = StageAlign.TOP_LEFT;
      this.stage.scaleMode = StageScaleMode.NO_SCALE;
      addEventListener(Event.ADDED_TO_STAGE, onStageAdded);

      var nc:NetConnection = new NetConnection();
      nc.connect(null);

      vid = new Video(640, 480);

      ns = new NetStream(nc);
      ns.client = customClient;
      ns.play(null);
      //ns.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
      vid.attachNetStream(ns);
      //ns.play('http://10.85.37.1:5005/flash-mjpeg/video.flv');

      addChild(vid);


    }

    private var processedHeaders:Boolean = false;
    private var flvBytes:ByteArray = new ByteArray();
    private function onStageAdded(e:Event):void {
      client.addEventListener("connect", onConnect);
      client.addEventListener("disconnect", onDisconnect);

      client.setJsEventCallbackName(jsEventCallbackName);

      client.sendLoadedEvent();

      /*var s:Socket = new Socket();
      s.timeout = 5000;
      s.addEventListener(Event.CONNECT, function(event:Event):void {
        s.writeUTFBytes("GET /webgui/video.flv HTTP/1.0\r\n");
        s.writeUTFBytes("\r\n");
        s.flush();
      });
      s.addEventListener(ProgressEvent.SOCKET_DATA, function (event:ProgressEvent):void {
        flvBytes.clear();
        s.readBytes(flvBytes);
        if (!processedHeaders) {
          flvBytes.position = ByteArrayUtils.indexOf(flvBytes, '\r\n\r\n') + 4;
          processedHeaders = true;
          return;
        }

        ExternalInterface.call(jsEventCallbackName, flvBytes.position);
        //ExternalInterface.call(jsEventCallbackName, ByteArrayUtils.hexdump(flvBytes, flvBytes.position));
        ExternalInterface.call(jsEventCallbackName, JSON.stringify(ns.info));
        ns.appendBytes(flvBytes);
      });

      s.connect("10.85.37.38", 80);*/
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
