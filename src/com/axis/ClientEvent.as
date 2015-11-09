package com.axis {
  import flash.events.Event;

  public class ClientEvent extends Event {
    public static const STOPPED:String = "stopped";
    public static const START_PLAY:String = "playing";
    public static const FRAME:String = "frame";
    public static const PAUSED:String = "paused";
    public static const META:String = "meta";

    public var data:Object;

    public function ClientEvent(type:String, data:Object = null, bubbles:Boolean = false, cancelable:Boolean = false) {
      super(type, bubbles, cancelable);
      this.data = data;
    }
  }
}
