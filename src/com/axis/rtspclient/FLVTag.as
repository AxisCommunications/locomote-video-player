package com.axis.rtspclient {
  import flash.events.Event;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

  public class FLVTag extends Event {
    public static const NEW_FLV_TAG:String = "newFlvTag";


    public var data:ByteArray;
    public var audio:Boolean;
    public var timestamp:uint;
    public var duration:uint;

    public function FLVTag(data:ByteArray, timestamp:uint, duration:uint, audio:Boolean) {
      super(NEW_FLV_TAG);

      data.position  = 0;
      this.data      = data;
      this.timestamp = timestamp;
      this.audio = audio;
      this.duration = duration;
    }

    public function copy():FLVTag {
      var newData:ByteArray = new ByteArray();
      var tmpPos:uint = data.position;
      data.position = 0;
      data.readBytes(newData);
      newData.position = 0;
      data.position = tmpPos;
      return new FLVTag(newData, this.timestamp, this.duration, this.audio);
    }
  }
}
