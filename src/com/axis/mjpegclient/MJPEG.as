package com.axis.mjpegclient {

  import com.axis.mjpegclient.Image;

  import com.axis.Logger;
  import flash.display.Loader;
  import flash.display.Bitmap;
  import flash.display.LoaderInfo;
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.utils.*;

  [Event(name="frame",type="flash.events.Event")]

  /**
   * Display object that can be fed JPEG data and show it centered.
   */
  public class MJPEG extends Sprite {

    public static const BUFFER_EMPTY:String = "bufferEmpty";
    public static const BUFFER_FULL:String = "bufferFull";
    public static const IMAGE_ERROR:String = "imageError";

    private const FLOATING_AVG_LENGTH:Number = 10;

    private var bufferSize:Number;
    private var paused:Boolean = false;

    private var loadTimer:uint;
    private var busy:Boolean = false;
    private var buffering:Boolean = true;
    private var timestamps:Vector.<Number> = new Vector.<Number>();
    private var loadTimes:Vector.<Number> = new Vector.<Number>();
    private var imageBuffer:Vector.<Image> = new Vector.<Image>();

    public function MJPEG(bufferSize:Number = 1000) {
      this.bufferSize = bufferSize;

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

    private function get firstTimestamp():Number {
      return this.timestamps.length > 0 ? this.timestamps[0] : 0;
    }

    private function get lastTimestamp():Number {
      return timestamps.length > 0 ? timestamps[timestamps.length - 1] : 0;
    }

    private function get firstLoadTime():Number {
      return this.loadTimes.length > 0 ? this.loadTimes[0] : -1;
    }

    private function get lastLoadTime():Number {
      return loadTimes.length > 0 ? loadTimes[loadTimes.length - 1] : -1;
    }

    private function destroyLoaders():void {
      removeLoaderEventListeners(backbuffer);
      removeChildren();
    }

    private function timeUntilLoad(image:Image):Number {
      if (this.timestamps.length === 0 || this.firstLoadTime === -1) {
        return 0;
      }
      var diff:Number = image.timestamp - this.lastTimestamp;
      var time:Number =  diff - (new Date().getTime() - this.lastLoadTime);
      return time <= 0 ? 0 : time;
    }

    public function pause():void {
      this.paused = true;
      this.loadNext();
    }

    public function resume():void {
      this.paused = false;
      this.loadNext();
    }

    public function getFps():Number {
      if (timestamps.length < 2) { return 0; }
      var loadTimesSum:Number = 0;
      var idx:int = timestamps.length - FLOATING_AVG_LENGTH;
      for (var i:uint = idx > 0 ? idx : 1; i < timestamps.length; i++) {
        loadTimesSum += timestamps[i] - timestamps[i - 1];
      }
      return 1000 * (timestamps.length - 1) / loadTimesSum;
    }

    public function getCurrentTime():Number {
      return timestamps.length > 0 ? this.lastTimestamp - this.firstTimestamp : 0;
    }

    public function setBuffer(bufferSize:Number):void {
      this.bufferSize = bufferSize;
      this.addImage();
    }

    public function getBuffer():Number {
      return this.bufferSize;
    }

    public function bufferedTime():Number {
      if (this.imageBuffer.length === 0) {
        return 0;
      }
      return this.imageBuffer[this.imageBuffer.length - 1].timestamp - this.imageBuffer[0].timestamp + this.timeUntilLoad(this.imageBuffer[0]);
    }

    public function addImage(image:Image = null):void {
      /* This function can be used to trigger reevaluation of the buffer state
       * if run without arguments */
      image !== null && this.imageBuffer.push(image);

      if (this.buffering && this.bufferedTime() > this.bufferSize) {
        dispatchEvent(new Event(MJPEG.BUFFER_FULL));
        this.buffering = false;
      }

      if (!this.buffering) {
        this.loadNext();
      }
    }

    private function loadNext():void {
      if (busy || this.imageBuffer.length === 0 || this.paused) {
        /* Already in the process of decoding an image, ignore this new image data */
        return;
      }
      busy = true;

      var image:Image = this.imageBuffer.shift()


      var timeout:Number = this.timeUntilLoad(image);

      this.loadTimes.push(new Date().getTime() + timeout);
      this.loadTimer = setTimeout(this.doLoad, timeout, image);
    }

    private function doLoad(image:Image):void {
      this.timestamps.push(image.timestamp);
      addLoaderEventListeners(backbuffer);
      backbuffer.loadBytes(image.data)
    }

    private function onLoadComplete(event:Event):void {
      var bitmap:Bitmap = event.currentTarget.content;
      if (bitmap != null) {
        bitmap.smoothing = true;
      }

      // Will crash if not removing listeners before swaping children
      removeLoaderEventListeners(backbuffer);
      this.swapChildren(frontBuffer, backbuffer);

      busy = false;

      if (this.imageBuffer.length === 0) {
        this.buffering = true;
        dispatchEvent(new Event(MJPEG.BUFFER_EMPTY));
      } else {
        this.loadNext();
      }

      dispatchEvent(new FrameEvent(bitmap));
    }

    private function onImageError(event:IOErrorEvent):void {
      busy = false;
      var loader:Loader = event.currentTarget.loader;
      removeLoaderEventListeners(loader);
      Logger.log('MJPEG failed to load image.', event.toString());
      dispatchEvent(new Event(MJPEG.IMAGE_ERROR));
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
      clearTimeout(this.loadTimer);
      // Remove graphics components, abort play
      destroyLoaders();
      busy = false;
    }
  }
}
