package com.axis.mjpgplayer {
  import com.axis.mjpgplayer.MJPGImage;

  import flash.display.Bitmap;
  import flash.display.LoaderInfo;
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

  public class MJPG extends Sprite {
    private const FLOATING_AVG_LENGTH:Number = 10;
    private const MAX_IMAGES:uint = 2;

    private var ipCam:IPCam;
    // All incoming raw image data chunks
    private var imgBuf:Vector.<Object> = new Vector.<Object>();
    // Children loaders which are available for use
    private var idleQueue:Vector.<MJPGImage> = new Vector.<MJPGImage>();
    // States
    private var firstImage:Boolean = true;
    private var playing:Boolean = false;
    // Statistics
    private var timestamps:Vector.<Number> = new Vector.<Number>();

    public function MJPG(ipCam:IPCam) {
      this.ipCam = ipCam;
      addEventListener(Event.ADDED_TO_STAGE, onStageAdded);
    }

    private function onStageAdded(e:Event):void {
      ExternalInterface.addCallback("getFps", getFps);
      createLoaders();
      stage.addEventListener(Event.RESIZE, resizeListener);
    }

    private function createLoaders():void {
      for (var i:uint = 0; i < MAX_IMAGES; i++) {
        var loader:MJPGImage = new MJPGImage();
        loader.cacheAsBitmap = false;
        loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
        loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onImageError);
        this.addChild(loader);
      }
    }

    private function destroyLoaders():void {
      for each (var loader:MJPGImage in getChildren()) {
        loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onLoadComplete);
        loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onImageError);
      }
      removeChildren();
    }

    private function resizeListener(e:Event):void {
      for each (var loader:MJPGImage in getChildren()) {
        scaleAndPosition(loader);
      }
    }

    public function getChildren():Array {
      var children:Array = [];
      for (var i:uint = 0; i < this.numChildren; i++) {
       children.push(this.getChildAt(i));
      }
      return children;
    }

    public function load(image:ByteArray):void {
      if (imgBuf.length >= MAX_IMAGES + 3) { imgBuf.shift(); }
      imgBuf.push({ data: image });

      if (!playing) {
        playing = true;
        for each (var loader:MJPGImage in getChildren()) {
          loader.data.inQue = true;
          idleQueue.push(loader);
        }
      }

      if (idleQueue.length > 0) {
        loadImage(idleQueue.shift(), imgBuf.shift());
      }
    }

    private function loadImage(loader:MJPGImage, obj:Object):void {
      loader.data.loading = true;
      loader.data.inQue = false;
      loader.data.loadTime = new Date().getTime();
      loader.loadBytes(obj.data as ByteArray);
      obj = null;
    }

    private function onLoadComplete(event:Event):void {
      if (!playing) { return; }

      var arr:Array = getChildren();
      var loader:MJPGImage = event.currentTarget.loader as MJPGImage;
      var bitmap:Bitmap = event.currentTarget.content;
      if (bitmap != null) {
        bitmap.smoothing = true;
      }
      loader.data.loading = false;

      scaleAndPosition(loader);

      timestamps.push(new Date().getTime());
      if (timestamps.length > FLOATING_AVG_LENGTH) { timestamps.shift(); }

      if (arr[arr.length - 1].data.loadTime <= loader.data.loadTime) {
        if (MAX_IMAGES > 2) {
          removeChild(loader);
          addChild(loader);
        } else if (MAX_IMAGES == 2) {
          this.swapChildren(arr[0], arr[1]);
        }
      }

      arr = getChildren();
      for (var i:uint = 0; i < arr.length - 1; i++) {
        loader = arr[i] as MJPGImage;

        if (loader.data.inQue == true || loader.data.loading) { continue; }

        if (imgBuf.length == 0) {
          loader.data.inQue = true;
          idleQueue.push(loader);
        } else {
          loadImage(loader, imgBuf.shift());
        }
      }

      if (firstImage) {
        ExternalInterface.call(ipCam.getJsEventCallbackName(), "started");
        firstImage = false;
      }
    }

    private function onImageError(event:IOErrorEvent):void {
      var loader:MJPGImage = event.currentTarget.loader as MJPGImage;
      loader.data.loading = false;
      if (imgBuf.length == 0) {
        loader.data.inQue = true;
        idleQueue.push(loader);
      } else {
        loadImage(loader, imgBuf.shift());
      }
    }

    private function scaleAndPosition(loader:MJPGImage):void {
      // Scale to fit stage
      var loaderAspectRatio:Number = loader.width / loader.height;
      var stageAspectRatio:Number = stage.stageWidth / stage.stageHeight;
      var scale:Number;
      if (loaderAspectRatio > stageAspectRatio) {
        scale = stage.stageWidth / loader.width;
      } else {
        scale = stage.stageHeight / loader.height;
      }
      loader.width *= scale;
      loader.height *= scale;

      // Center on stage
      loader.x = (stage.stageWidth - loader.width) / 2;
      loader.y = (stage.stageHeight - loader.height) / 2;
    }

    public function reset(clear:Boolean = false):void {
      playing = false;
      firstImage = true;
      idleQueue.length = 0;

      while (imgBuf.length != 0) {
        imgBuf.shift();
      }

      for each (var loader:MJPGImage in getChildren()) {
        loader.data.loading = false;
        loader.data.inQue = false;
        loader.data.loadTime = 0.0;
      }

      if (clear) {
        destroyLoaders();
        createLoaders();
      }
    }

    public function getFps():Number {
      if (timestamps.length < 2) { return 0; }
      var loadTimesSum:Number = 0;
      for (var i:uint = 1; i < timestamps.length; i++) {
        loadTimesSum += timestamps[i] - timestamps[i - 1];
      }
      return 1000 * (timestamps.length - 1) / loadTimesSum;
    }
  }
}
