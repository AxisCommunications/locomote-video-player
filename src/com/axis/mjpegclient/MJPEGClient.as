package com.axis.mjpegclient {

  import com.axis.Logger;
  import com.axis.IClient;
  import com.axis.ClientEvent;
  import com.axis.mjpegclient.Image;
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
    private var streamBuffer:Array = new Array();
    private var frameByFrame:Boolean = false;
    private var connectionBroken:Boolean = false;

    public function MJPEGClient(urlParsed:Object) {
      this.handle = new Handle(urlParsed);
      this.mjpeg = new MJPEG(Player.config.buffer * 1000);
      this.frameByFrame = Player.config.frameByFrame;

      mjpeg.addEventListener("frame", onFrame);
      mjpeg.addEventListener(MJPEG.BUFFER_EMPTY, onBufferEmpty);
      mjpeg.addEventListener(MJPEG.BUFFER_FULL, onBufferFull);
      handle.addEventListener(Image.NEW_IMAGE_EVENT, onImage);
      handle.addEventListener(Handle.CONNECTED, onConnected);
    }

    public function getDisplayObject():DisplayObject {
      return this.mjpeg;
    };

    public function getCurrentTime():Number {
      return this.mjpeg.getCurrentTime();
    }

    public function bufferedTime():Number {
      return this.mjpeg.bufferedTime();
    }

    public function start(options:Object):Boolean {
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

    public function setFrameByFrame(frameByFrame:Boolean):Boolean {
      this.frameByFrame = frameByFrame;
      return true;
    }

    public function setBuffer(seconds:Number):Boolean {
      return false;
    }

    public function hasVideo():Boolean {
      return true;
    }

    public function hasAudio():Boolean {
      return false;
    }

    public function currentFPS():Number {
      return mjpeg.getFps();
    }

    public function playFrames(timestamp:Number):void {
      while (this.streamBuffer.length > 0 && this.streamBuffer[0].timestamp <= timestamp) {
        mjpeg.addImage(this.streamBuffer.shift());
      }
      this.stopIfDone();
    }

    private function onImage(image:Image):void {
      if (this.frameByFrame) {
        this.streamBuffer.push(image);
        dispatchEvent(new ClientEvent(ClientEvent.FRAME, image.timestamp));
      } else {
        mjpeg.addImage(image);
        this.stopIfDone();
      }
    }

    private function stopIfDone():void {
      if (this.streamBuffer.length === 0 && this.connectionBroken && mjpeg.bufferedTime() === 0) {
        mjpeg.clear();
        dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
      }
    }

    private function onConnected(e:Event):void {
      handle.addEventListener(Handle.CLOSED, onCLosed);
    }

    private function onCLosed(e:Event):void {
      this.connectionBroken = true;
      this.mjpeg.setBuffer(0);
      this.stopIfDone();
    }

    private function onFrame(e:FrameEvent):void {
      state = "playing";
      dispatchEvent(new ClientEvent(ClientEvent.META, {
        width: e.getFrame().width,
        height: e.getFrame().height
      }));
      dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
      mjpeg.removeEventListener("frame", onFrame);
    }

    private function onBufferEmpty(e:Event):void {
      Logger.log('MJPEG status buffer empty');
      dispatchEvent(new ClientEvent(ClientEvent.PAUSED, { 'reason': 'buffering' }));
      this.stopIfDone();
    }

    private function onBufferFull(e:Event):void {
      Logger.log('MJPEG status buffer full');
      dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
    }

  }
}
