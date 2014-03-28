package {

  import com.axis.rtspclient.HTTPClient;
  import flash.display.Sprite;
  import flash.display.LoaderInfo;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.events.Event;
  import flash.events.ErrorEvent;
  import flash.events.IOErrorEvent;
  import flash.events.SecurityErrorEvent;
  import flash.events.NetStatusEvent;
  import flash.events.ActivityEvent;
  import flash.events.ProgressEvent;
  import flash.events.StatusEvent;
  import flash.events.SampleDataEvent;
  import flash.external.ExternalInterface;
  import flash.media.Video;
  import flash.media.Microphone;
  import flash.media.Sound;
  import flash.media.SoundCodec;
  import flash.net.NetStream;
  import flash.net.NetConnection;
  import flash.net.Socket;
  import flash.utils.ByteArray;
  import flash.utils.getTimer;

  import com.axis.rtspclient.ByteArrayUtils;
  import com.axis.rtspclient.BitArray;

  [SWF(frameRate="60")]

  public class Player extends Sprite {
    private var jsEventCallbackName:String = "console.log";
    private var client:HTTPClient = new HTTPClient();
    private var transmit:Socket;

    private var vid:Video;
    private static var ns:NetStream;
    private var audio:ByteArray = new ByteArray();
    private var sound:Sound;

    private var exponentLookup:Array = [
      0, 0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3,
      4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
      6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
      6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
      6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
      6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
      7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
    ];

    public function Player() {

      this.stage.align = StageAlign.TOP_LEFT;
      this.stage.scaleMode = StageScaleMode.NO_SCALE;
      addEventListener(Event.ADDED_TO_STAGE, onStageAdded);
      ExternalInterface.addCallback("stop", stop);

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

      var mic:Microphone = Microphone.getMicrophone();
      mic.rate = 8;
      mic.gain = 80;
      mic.codec = SoundCodec.PCMU;
      ExternalInterface.call('console.log', 'codec:', mic.codec);
      mic.setSilenceLevel(0, -1);
      mic.addEventListener(StatusEvent.STATUS, this.onMicStatus);
      mic.addEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleData);

      transmit = new Socket();
      transmit.addEventListener(Event.CONNECT, transmitConnect);
      transmit.addEventListener(Event.CLOSE, transmitClose);
      transmit.addEventListener(ProgressEvent.SOCKET_DATA, transmitData);
      transmit.addEventListener(IOErrorEvent.IO_ERROR, onError);
      transmit.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);

      //transmit.connect('192.168.180.193', 80);
    }

    private function stop():void {
      transmit.close();
    }

    private function transmitConnect(event:Event):void {
      ExternalInterface.call('console.log', 'transmitConnect');
      transmit.writeUTFBytes("POST /axis-cgi/audio/transmit.cgi HTTP/1.0\r\n");
      transmit.writeUTFBytes("Content-Type: audio/basic\n");
      transmit.writeUTFBytes("Content-Length: 9999999\n");
      transmit.writeUTFBytes("Connection: Keep-Alive\n");
      transmit.writeUTFBytes("Cache-Control: no-cache\n");
      transmit.writeUTFBytes("Authorization: Basic cm9vdDo1OE5CN1VLMw==\n");
      transmit.writeUTFBytes("\r\n");
    }

    private function transmitClose(event:Event):void {
      ExternalInterface.call(jsEventCallbackName, "transmitClose");
    }

    private function transmitData(event:ProgressEvent):void {
      ExternalInterface.call(jsEventCallbackName, 'DATA ON AUDIO CHANNEL');
      var dba:ByteArray = new ByteArray();
      transmit.readBytes(dba);
      ExternalInterface.call(jsEventCallbackName, dba.toString());
    }

    private function onStageAdded(e:Event):void {
      client.addEventListener("connect", onConnect);
      client.addEventListener("disconnect", onDisconnect);

      client.setJsEventCallbackName(jsEventCallbackName);

      client.sendLoadedEvent();
    }

    private function mulawEncode(sample:Number):uint
    {
      var bias:uint = 0x84;
      var clamp:uint = 32635;

      var short:int = sample * 0x7fff;
      var negative:uint = (short & (0x1 << 31)) ? 1 : 0;

      if (negative) {
        short = -short;
      }

      if (short > clamp) {
        short = clamp; // Clamp the value
      }

      short += bias; // u-law bias

      var exponent:int = exponentLookup[(short >>> 7) & 0xFF];
      var mantissa:int = (short >>> (exponent + 3)) & 0x0F;
      var encoded:uint = ~((negative << 7) | (exponent << 4) | mantissa);

      if (encoded & 0xFF === 0) {
        encoded = 0x02;
      }
      return encoded;
    }

    private function onMicSampleData(event:SampleDataEvent):void
    {
      if (!transmit.connected) {
        return;
      }
      ExternalInterface.call('console.log', 'sample audio data');
      while (event.data.bytesAvailable) {
        var enc:uint = mulawEncode(event.data.readFloat());
        transmit.writeByte(enc);
      }
      transmit.flush();
    }

    private function onMicStatus(event:StatusEvent):void
    {
      ExternalInterface.call('console.log', 'Mic status', event);
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

    private function onError(e:ErrorEvent):void {
      ExternalInterface.call(jsEventCallbackName, "TransmitSocket failed");
    }
  }
}
