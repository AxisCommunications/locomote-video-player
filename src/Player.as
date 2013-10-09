package {

  import com.axis.rtspclient.HTTPClient;
  import flash.display.Sprite;
  import flash.display.LoaderInfo;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.events.Event;
  import flash.external.ExternalInterface;

  [SWF(frameRate="60")]

  public class Player extends Sprite {
    private var client:HTTPClient = new HTTPClient();

    public function Player() {
      this.stage.align = StageAlign.TOP_LEFT;
      this.stage.scaleMode = StageScaleMode.NO_SCALE;
      addEventListener(Event.ADDED_TO_STAGE, onStageAdded);
    }

    private function onStageAdded(e:Event):void {
      client.addEventListener("connect", onConnect);
      client.addEventListener("disconnect", onDisconnect);

      if (ExternalInterface.available) {
        var jsEventCallbackName:String = LoaderInfo(this.parent.loaderInfo).parameters["eventCallbackName"];
        if (jsEventCallbackName != null) {
          client.setJsEventCallbackName(jsEventCallbackName);
        }
      }
      client.sendLoadedEvent();
    }

    private function onDisconnect(e:Event):void {
      trace('onDisconnect', e);
    }

    private function onConnect(e:Event):void {
      trace('onConnect', e);
    }

  }

}
