package com.axis.mjpgplayer {

  import com.axis.mjpgplayer.MJPGImage;
  import flash.display.Bitmap;
  import flash.display.LoaderInfo;
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.utils.ByteArray;
  import flash.external.ExternalInterface;

  public class MJPG extends Sprite {

    private var ipCam:IPCam;
    private var maxImages:uint = 2;
    private var firstImage:Boolean = true;
    private var imgBuf:Vector.<Object> = new Vector.<Object>();
    private var idleQue:Vector.<MJPGImage> = new Vector.<MJPGImage>();
    private var playing:Boolean = false;

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
      for (var i:uint = 0; i < maxImages; i++) {
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
      if (imgBuf.length >= maxImages + 3) {
        imgBuf.shift();
      }
      imgBuf.push({ data: image });

      if (!playing) {
        playing = true;
        for each (var loader:MJPGImage in getChildren()) {
          loader.data.inQue = true;
          idleQue.push(loader);
        }
      }

      if (idleQue.length > 0) {
        loadImage(idleQue.shift(), imgBuf.shift());
      }
    }

    private function loadImage(loader:MJPGImage, obj:Object):void {
      loader.data.loading = true;
      loader.data.inQue = false;
      loader.data.loadTime = new Date().getTime();
      loader.loadBytes(obj.data as ByteArray);
      obj = null;
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

      var curTime:Number = new Date().getTime();
      if (arr[arr.length - 1].data.loadTime <= loader.data.loadTime) {
        if (maxImages > 2) {
          removeChild(loader);
          addChild(loader);
        } else if (maxImages == 2) {
          this.swapChildren(arr[0], arr[1]);
        }
      }

      arr = getChildren();
      for (var i:uint = 0; i < arr.length - 1; i++) {
        loader = arr[i] as MJPGImage;

        if (loader.data.inQue == true || loader.data.loading) { continue; }

        if (imgBuf.length == 0) {
          loader.data.inQue = true;
          idleQue.push(loader);
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
        idleQue.push(loader);
      } else {
        loadImage(loader, imgBuf.shift());
      }
    }

    public function reset(clear:Boolean = false):void {
      playing = false;
      firstImage = true;
      idleQue.length = 0;

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
      return 1337;
    }

  }

}
