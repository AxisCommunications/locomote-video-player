package com.axis.mjpgplayer
{
  import com.axis.mjpgplayer.MJPGImage;
  import flash.display.Bitmap;
  import flash.display.LoaderInfo;
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.utils.ByteArray;
  import flash.external.ExternalInterface;

  public class MJPG extends Sprite
  {
    private var ipCam:IPCam;
    private var maxImages:uint = 2;
    private var firstImage:Boolean = true;
    private var imgBuf:Vector.<Object> = new Vector.<Object>();
    private var idleQue:Vector.<MJPGImage> = new Vector.<MJPGImage>();
    private var _playing:Boolean = false;

    // Statistics Variables
    private var sTime:Number = 0;
    private var decTime:uint = 0;
    private var _fRecCount:uint = 0;
    private var _fDecCount:uint = 0;
    private var _fps:Number = 0.0;

    public function MJPG(ipCam:IPCam)
    {
      this.ipCam = ipCam;
      addEventListener(Event.ADDED_TO_STAGE, onStageAdded);
    }

    private function onStageAdded(e:Event):void
    {
      ExternalInterface.addCallback("getFps", getFps);

      for (var i:uint = 0; i < maxImages; i++)
      {
        var loader:MJPGImage = new MJPGImage();
        loader.cacheAsBitmap = false;
        loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
        loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onImageError);
        this.addChild(loader);
      }
    }

    public function getChildren():Array
    {
       var children:Array = [];

       for (var i:uint = 0; i < this.numChildren; i++)
        children.push(this.getChildAt(i));

       return children;
    }

    [Bindable(event='framesDecChanged')]
    public function get framesDecoded():uint
    {
      return _fDecCount;
    }

    private function updateDecFrames(v:uint):void
    {
      _fDecCount = v;
      dispatchEvent(new Event("framesDecChanged"));
    }

    [Bindable(event='playingChanged')]
    public function get playing():Boolean
    {
      return _playing;
    }

    private function updatePlaying(v:Boolean):void
    {
      _playing = v;
      dispatchEvent(new Event("playingChanged"));
    }

    [Bindable(event='fpsChanged')]
    public function get fps():Number
    {
      return _fps;
    }

    public function getFps():Number
    {
      return _fps;
    }

    private function updateFps(v:Number):void
    {
      _fps = v;
      dispatchEvent(new Event("fpsChanged"));
    }

    private function loadImage(loader:MJPGImage, obj:Object):void
    {
      loader.data.loading = true;
      loader.data.inQue = false;
      loader.data.loadTime = new Date().getTime();
      loader.data.frame = obj.frame;
      loader.loadBytes(obj.data as ByteArray);
      obj = null;
    }

    public function load(image:ByteArray):void
    {
      if (imgBuf.length >= maxImages + 3)
      {
        var obj:Object = imgBuf.shift();
        obj = null;
      }
      _fRecCount++;
      imgBuf.push({frame: _fRecCount, data: image});

      if (!playing)
      {
        sTime = new Date().getTime();
        decTime = 0;
        _fRecCount = 1;
        updateDecFrames(0);
        updatePlaying(true);

        var arr:Array = getChildren();
        var loader:MJPGImage = null;
        for each (loader in arr)
        {
          loader.data.inQue = true;
          idleQue.push(loader);
        }
      }

      if (idleQue.length > 0)
      {
        loader = idleQue.shift() as MJPGImage;
        loadImage(loader, imgBuf.shift());
      }
    }

    private function onLoadComplete(event:Event):void
    {
      if (!playing)
      {
        return;
      }

      var arr:Array = getChildren();
      var loader:MJPGImage = event.currentTarget.loader as MJPGImage;
      var bitmap:Bitmap = event.currentTarget.content;
      if (bitmap != null)
      {
        bitmap.smoothing = true;
      }
      loader.data.loading = false;

      // Scale to fit stage
      var loaderAspectRatio:Number = loader.width / loader.height;
      var stageAspectRatio:Number = stage.stageWidth / stage.stageHeight;
      var scale:Number;
      if (loaderAspectRatio > stageAspectRatio)
      {
        scale = stage.stageWidth / loader.width;
      }
      else
      {
        scale = stage.stageHeight / loader.height;
      }
      loader.width *= scale;
      loader.height *= scale;

      // Center on stage
      this.x = (stage.stageWidth - loader.width) / 2;
      this.y = (stage.stageHeight - loader.height) / 2;

      var curTime:Number = new Date().getTime();
      decTime += curTime - loader.data.loadTime;
      if (arr[arr.length - 1].data.loadTime <= loader.data.loadTime)
      {
        if (maxImages > 2)
        {
          removeChild(loader);
          addChild(loader);
        }
        else if (maxImages == 2)
        {
          this.swapChildren(arr[0], arr[1]);
        }
        updateDecFrames(framesDecoded + 1);
        updateFps((framesDecoded * 1000) / (curTime - sTime));
      }

      arr = getChildren();
      for (var i:uint = 0; i < arr.length - 1; i++)
      {
        loader = arr[i] as MJPGImage;
        if (loader.data.inQue == true || loader.data.loading)
        {
          continue;
        }

        if (imgBuf.length == 0)
        {
          loader.data.inQue = true;
          idleQue.push(loader);
        }
        else
        {
          loadImage(loader, imgBuf.shift());
        }
      }

      if (firstImage) {
        ExternalInterface.call(ipCam.getJsEventCallbackName(), "started");
        firstImage = false;
      }
    }

    private function onImageError(event:IOErrorEvent):void
    {
      var loader:MJPGImage = event.currentTarget.loader as MJPGImage;
      loader.data.loading = false;
      if (imgBuf.length == 0)
      {
        loader.data.inQue = true;
        idleQue.push(loader);
      }
      else
        loadImage(loader, imgBuf.shift());
    }

    public function reset(clear:Boolean = false):void
    {
      firstImage = true;
      updatePlaying(false);
      idleQue.length = 0;

      while (imgBuf.length != 0)
      {
        _fRecCount--;
        var obj:Object = imgBuf.shift();
        obj = null;
      }

      var arr:Array = getChildren();
      for each (var loader:MJPGImage in arr)
      {
        if (loader.data.loading)
        {
          updateDecFrames(framesDecoded + 1);
        }
        loader.data.loading = false;
        loader.data.inQue = false;
        loader.data.loadTime = 0.0;

        if (clear)
        {
          loader.unload();
        }
      }

      updateFps((framesDecoded * 1000) / (new Date().getTime() - sTime));

      var recvFps:Number = (_fRecCount * 1000) / (new Date().getTime() - sTime);
    }
  }

}
