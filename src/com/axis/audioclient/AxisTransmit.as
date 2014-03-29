package com.axis.audioclient {

  import flash.events.Event;
  import flash.events.ProgressEvent;
  import flash.events.ErrorEvent;
  import flash.events.SampleDataEvent;
  import flash.events.StatusEvent;
  import flash.events.SecurityErrorEvent;
  import flash.events.IOErrorEvent;
  import flash.net.Socket;
  import flash.media.Microphone;
  import flash.media.SoundCodec;
  import flash.utils.ByteArray;

  import com.axis.codec.g711;

  public class AxisTransmit {
    private var conn:Socket = new Socket();

    public function AxisTransmit() {
      var mic:Microphone = Microphone.getMicrophone();
      mic.rate = 8;
      mic.setSilenceLevel(0, -1);
      mic.addEventListener(StatusEvent.STATUS, this.onMicStatus);
      mic.addEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleData);
    }

    private function onMicStatus(event:StatusEvent):void {
      trace('mic status changed: ', event);
    }

    public function start(url:String):void {
      if (conn.connected) {
        trace('already connected');
        return;
      }

      conn = new Socket();
      conn.addEventListener(Event.CONNECT, onConnected);
      conn.addEventListener(Event.CLOSE, onClosed);
      conn.addEventListener(ProgressEvent.SOCKET_DATA, onRequestData);
      conn.addEventListener(IOErrorEvent.IO_ERROR, onError);
      conn.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);

      conn.connect('10.0.1.102', 80);
    }

    public function stop():void {
      if (!conn.connected) {
        trace('not connected');
        return;
      }

      conn.close();
    }

    private function onConnected(event:Event):void {
      trace('axis audio connected');
      conn.writeUTFBytes("POST /axis-cgi/audio/transmit.cgi HTTP/1.0\r\n");
      conn.writeUTFBytes("Content-Type: audio/basic\n");
      conn.writeUTFBytes("Content-Length: 9999999\n");
      conn.writeUTFBytes("Connection: Keep-Alive\n");
      conn.writeUTFBytes("Cache-Control: no-cache\n");
      conn.writeUTFBytes("Authorization: Basic cm9vdDpwYXNz\n");
      conn.writeUTFBytes("\r\n");
    }

    private function onClosed(event:Event):void {
      trace('axis audio closed');
    }

    private function onMicSampleData(event:SampleDataEvent):void
    {
      if (!conn.connected) {
        return;
      }

      while (event.data.bytesAvailable) {
        var encoded:uint = g711.linearToMulaw(event.data.readFloat());
        conn.writeByte(encoded);
      }

      conn.flush();
    }

    private function onRequestData(event:ProgressEvent):void {
      var d:ByteArray = new ByteArray();
      conn.readBytes(d);
      trace(d.toString());
    }

    private function onError(e:ErrorEvent):void {
      trace('axis transmit error');
    }
  }
}
