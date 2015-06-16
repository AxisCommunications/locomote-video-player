package com.axis.mjpegclient {

  import com.axis.Logger;
  import com.axis.IClient;
  import com.axis.ClientEvent;
  import com.axis.mjpegclient.Handle;
  import com.axis.mjpegclient.MJPEG;
  import flash.display.DisplayObject;
  import flash.display.Sprite;
  import flash.display.LoaderInfo;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.events.Event;
  import flash.events.EventDispatcher;

  public class MJPEGClient extends EventDispatcher implements IClient {
    private var handle:Handle;
    private var mjpeg:MJPEG;
    private var state:String = "initial";

    public function MJPEGClient(urlParsed:Object) {
      this.handle = new Handle(urlParsed);
      this.mjpeg = new MJPEG();

      mjpeg.addEventListener("frame", onFrame);
      handle.addEventListener("image", onImage);
    }

    public function getDisplayObject():DisplayObject {
      return this.mjpeg;
    };

    public function start():Boolean {
      this.handle.connect();
      state = "connecting";
      return true;
    }

    public function stop():Boolean {
      this.handle.stop();
      if (state !== "playing") {
        /* If we're not playing, we're never gonna get the 'disconnect' event. Fire stopped now in that case */
        dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
      }

      state = "stopped";
      return false;
    }

    public function seek(position:Number):Boolean {
      return false;
    }

    public function pause():Boolean {
      handle.removeEventListener("image", onImage);
      dispatchEvent(new ClientEvent(ClientEvent.PAUSED, { 'reason': 'user' }));
      return true;
    }

    public function resume():Boolean {
      if (handle.hasEventListener("image")) {
        return false;
      }

      dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
      handle.addEventListener("image", onImage);
      return true;
    }

    public function setBuffer(seconds:Number):Boolean {
      return false;
    }

    public function hasVideo():Boolean {
      return true;
    };

    public function hasAudio():Boolean {
      return false;
    };

    public function currentFPS():Number {
      return mjpeg.getFps();
    };

    public function currentTime():Number {
      /* not yet implemented : mjpeg.getCurrentTime() */
      return null;
    };

    private function onDisconnect(e:Event):void {
      mjpeg.clear();
      dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
    }

    private function onImage(e:Event):void {
      mjpeg.load(handle.image);
    }

    private function onFrame(e:FrameEvent):void {
      state = "playing";
      dispatchEvent(new ClientEvent(ClientEvent.META, {
        width: e.getFrame().width,
        height: e.getFrame().height
      }));
      dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
      handle.addEventListener("disconnect", onDisconnect);
      mjpeg.removeEventListener("frame", onFrame);
    }
  }
}
