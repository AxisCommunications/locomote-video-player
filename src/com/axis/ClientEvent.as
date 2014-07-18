package com.axis {
  import flash.events.Event;

  public class ClientEvent extends Event {
    public static const NETSTREAM_CREATED:String = "NetStreamCreated";
    public static const STOPPED:String = "Stopped";
    public static const START_PLAY:String = "Playing";

    public var data:Object;

    public function ClientEvent(type:String, data:Object = null, bubbles:Boolean = false, cancelable:Boolean = false) {
      super(type, bubbles, cancelable);
      this.data = data;
    }
  }
}