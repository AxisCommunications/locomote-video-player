package com.axis.mjpegclient {

  import com.axis.mjpegclient.Image;

  import com.axis.Logger;
  import flash.display.Loader;
  import flash.display.Bitmap;
  import flash.display.LoaderInfo;
  import flash.display.Sprite;
  import flash.events.TimerEvent;
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

    private const ALPHA:Number = 0.2;

    private var bufferSize:Number;
    private var paused:Boolean = false;

    private var loadTimer:uint;
    private var busy:Boolean = false;
    private var buffering:Boolean = true;
    private var timestamps:Vector.<Number> = new Vector.<Number>();
    private var loadTimes:Vector.<Number> = new Vector.<Number>();
    private var imageBuffer:Vector.<Image> = new Vector.<Image>();
    private var ratePeriodMs:uint = 10;
    private var rateTimer:Timer = new Timer(ratePeriodMs, 0);
    private var avgPeriod:uint = 10000;//some "sane" default

    public function MJPEG(bufferSize:Number = 1000) {
      this.bufferSize = bufferSize;

      createLoaders();

      /* needed for double-click (fullscreen) to work */
      this.mouseChildren = false;
      this.doubleClickEnabled = true;

      this.rateTimer.addEventListener(TimerEvent.TIMER, render);
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
      return this.timestamps.length > 0 ? this.timestamps[0] : imageBuffer[0].timestamp;
    }

    private function get lastTimestamp():Number {
      return timestamps.length > 0 ? timestamps[timestamps.length - 1] : imageBuffer[0].timestamp;
    }

    private function get firstLoadTime():Number {
      return this.loadTimes.length > 0 ? this.loadTimes[0] : getTimer();
    }

    private function get lastLoadTime():Number {
      return loadTimes.length > 0 ? loadTimes[loadTimes.length - 1] : getTimer();
    }

    private function destroyLoaders():void {
      removeLoaderEventListeners(backbuffer);
      removeChildren();
    }

    private function shouldLoad(image:Image):Boolean {
      return getTimer() - firstLoadTime >= image.timestamp - firstTimestamp;
    }

    public function pause():void {
      this.paused = true;
      this.rateTimer.reset();
    }

    public function resume():void {
      this.paused = true;
      this.rateTimer.start();
    }

    public function getFps():Number {
      return 1000 / avgPeriod;
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
      return this.imageBuffer[this.imageBuffer.length - 1].timestamp - this.imageBuffer[0].timestamp;
    }

    public function addImage(image:Image = null):void {
      /* This function can be used to trigger reevaluation of the buffer state
       * if run without arguments */
      image !== null && this.imageBuffer.push(image);

      if (this.buffering && this.bufferedTime() > this.bufferSize) {
        dispatchEvent(new Event(MJPEG.BUFFER_FULL));
        this.buffering = false;
      }

      if (!this.buffering && !this.paused) {
        this.rateTimer.start();
      }
    }

    private function loadNext():void {
      if (busy || imageBuffer.length === 0) {
        /* Already in the process of decoding an image, ignore this new image data */
        return;
      }

      /* Find last image that should have been displayed, and discard any previous ones */
      var image:Image;
      for (var i:uint = 0; i < imageBuffer.length && shouldLoad(imageBuffer[i]); i++) {
        image = imageBuffer[i];
      }
      
      if (image) {
        imageBuffer.splice(0, i);//i is already incremented on last loop iteration
        loadTimes.push(getTimer());
        doLoad(image);
      }
    }

    private function doLoad(image:Image):void {
      busy = true;
      avgPeriod = (1 - ALPHA) * avgPeriod + ALPHA * (image.timestamp - lastTimestamp);
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
        this.rateTimer.reset();
        dispatchEvent(new Event(MJPEG.BUFFER_EMPTY));
      }

      dispatchEvent(new FrameEvent(bitmap));
    }

    private function render(e:TimerEvent):void {
      this.loadNext();
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
      // Remove graphics components, abort play
      destroyLoaders();
      busy = false;
    }
  }
}
