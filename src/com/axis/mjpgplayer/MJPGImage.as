package com.axis.mjpgplayer {
  import flash.display.Loader;

  public class MJPGImage extends Loader {
    public var data:ImageData;

    public function MJPGImage() {
      this.cacheAsBitmap = false;
      this.data = new ImageData();
    }
  }
}
