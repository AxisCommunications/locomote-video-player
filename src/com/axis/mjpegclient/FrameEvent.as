package com.axis.mjpegclient {
  import flash.display.Bitmap;
  import flash.events.Event;

  public class FrameEvent extends Event {
    private var frame:Bitmap;
    public function FrameEvent(frame:Bitmap) {
      super("frame");
      this.frame = frame;
    }

    public function getFrame():Bitmap {
      return this.frame;
    }
  }
}
