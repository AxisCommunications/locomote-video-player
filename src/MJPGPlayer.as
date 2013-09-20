package {

  import com.axis.mjpgplayer.IPCam;
  import com.axis.mjpgplayer.MJPG;
  import flash.display.Sprite;
  import flash.display.LoaderInfo;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.events.Event;
  import flash.external.ExternalInterface;

  [SWF(frameRate="60")]

  public class MJPGPlayer extends Sprite {
    private var cam:IPCam = new IPCam();
    private var mjpg:MJPG = new MJPG(cam);

    public function MJPGPlayer() {
      this.stage.align = StageAlign.TOP_LEFT;
      this.stage.scaleMode = StageScaleMode.NO_SCALE;
      addEventListener(Event.ADDED_TO_STAGE, onStageAdded);
    }

    private function onStageAdded(e:Event):void {
      this.addChild(mjpg);
      cam.addEventListener("image", onImage);
      cam.addEventListener("disconnect", onDisconnect);
      cam.addEventListener("clear", onClear);

      if (ExternalInterface.available) {
        var jsEventCallbackName:String = LoaderInfo(this.parent.loaderInfo).parameters["eventCallbackName"];
        if (jsEventCallbackName != null) {
          cam.setJsEventCallbackName(jsEventCallbackName);
        }
      }
      cam.sendLoadedEvent();
    }

    private function onDisconnect(e:Event):void {
      mjpg.reset(false);
    }

    private function onImage(e:Event):void {
      mjpg.load(cam.image);
    }

    private function onClear(e:Event):void {
      mjpg.reset(true);
    }
  }

}
