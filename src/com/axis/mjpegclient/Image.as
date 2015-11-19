package com.axis.mjpegclient {
  import flash.utils.ByteArray;
  import flash.events.Event;

  public class Image extends Event {

    public static const NEW_IMAGE_EVENT:String = "image";

    public var data:ByteArray;
    public var timestamp:Number;

    public function Image(data:ByteArray, timestamp:Number) {
      super(NEW_IMAGE_EVENT);
      this.data = data;
      this.timestamp = timestamp;
    }
  }
}
