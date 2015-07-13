package com.axis.mjpegclient {

  import flash.display.Loader;
  import flash.display.Bitmap;
  import flash.display.LoaderInfo;
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.utils.ByteArray;

  import com.axis.Logger;

  [Event(name="frame",type="flash.events.Event")]

  /**
   * Display object that can be fed JPEG data and show it centered.
   */
  public class MJPEG extends Sprite {

    private const FLOATING_AVG_LENGTH:Number = 10;

    private var busy:Boolean = false;
    private var timestamps:Vector.<Number> = new Vector.<Number>();
    private var firstTimestamp:Number = -1;

    public function MJPEG() {
      createLoaders();

      /* needed for double-click (fullscreen) to work */
      this.mouseChildren = false;
      this.doubleClickEnabled = true;
    }

    private function createLoaders():void {
      addChild(new Loader()); // Backbuffer
      addChild(new Loader()); // Frontbuffer
    }

    private function get backbuffer():Loader {
      return getChildAt(0) as Loader;
    }

    private function get frontBuffer():Loader {
      return getChildAt(1) as Loader;
    }

    private function destroyLoaders():void {
      removeLoaderEventListeners(backbuffer);
      removeChildren();
    }

    public function load(image:ByteArray):void {
      if (busy) {
        /* Already in the process of decoding an image, ignore this new image data */
        return;
      }

      addLoaderEventListeners(backbuffer);
      busy = true;
      backbuffer.loadBytes(image);
    }

    private function onLoadComplete(event:Event):void {
      busy = false;
      var loader:Loader = event.currentTarget.loader;
      removeLoaderEventListeners(loader);

      var bitmap:Bitmap = event.currentTarget.content;
      if (bitmap != null) {
        bitmap.smoothing = true;
      }

      this.swapChildren(frontBuffer, backbuffer);

      var time:Number = new Date().getTime();
      timestamps.push(time);
      if (firstTimestamp == -1) {
        firstTimestamp = time;
      }
      if (timestamps.length > FLOATING_AVG_LENGTH) { timestamps.shift(); }

      dispatchEvent(new FrameEvent(bitmap));
    }

    private function onImageError(event:IOErrorEvent):void {
      busy = false;
      var loader:Loader = event.currentTarget.loader;
      removeLoaderEventListeners(loader);
    }

    private function addLoaderEventListeners(loader:Loader):void {
      loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
      loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onImageError);
    }

    private function removeLoaderEventListeners(loader:Loader):void {
      loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onLoadComplete);
      loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onImageError);
    }

    public function clear():void {
      // Remove graphics components, abort play
      destroyLoaders();
      busy = false;
    }

    public function getFps():Number {
      if (timestamps.length < 2) { return 0; }
      var loadTimesSum:Number = 0;
      for (var i:uint = 1; i < timestamps.length; i++) {
        loadTimesSum += timestamps[i] - timestamps[i - 1];
      }
      return 1000 * (timestamps.length - 1) / loadTimesSum;
    }

    public function getCurrentTime():Number {
      return timestamps.length > 0 ? timestamps[timestamps.length - 1] - firstTimestamp : 0;
    }
  }
}
