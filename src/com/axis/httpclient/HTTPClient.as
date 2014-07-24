package com.axis.httpclient {
  import com.axis.ClientEvent;
  import com.axis.IClient;

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.NetStatusEvent;
  import flash.media.Video;
  import flash.net.NetConnection;
  import flash.net.NetStream;

  public class HTTPClient extends EventDispatcher implements IClient {
    private var urlParsed:Object;
    private var video:Video;
    private var nc:NetConnection;
    private var ns:NetStream;

    public function HTTPClient(video:Video, urlParsed:Object) {
      this.urlParsed = urlParsed;
      this.video = video;
    }

    public function start():Boolean {
      trace('HTTPClient: playing:', urlParsed.full);

      nc = new NetConnection();
      nc.connect(null);
      nc.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);

      this.ns = new NetStream(nc);
      this.ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
      dispatchEvent(new ClientEvent(ClientEvent.NETSTREAM_CREATED, { ns : this.ns }));

      this.video.attachNetStream(this.ns);

      ns.play(urlParsed.full);
      return true;
    }

    public function stop():Boolean {
      ns.dispose();
      nc.close();
      return true;
    }

    public function pause():Boolean {
      ns.pause();
      return true;
    }

    public function resume():Boolean {
      ns.resume();
      return true;
    }

    public function forceBuffering():Boolean {
      this.ns.pause();
      this.ns.resume();
      return true;
    }

    private function onConnectionStatus(event:NetStatusEvent):void {
      if ('NetConnection.Connect.Closed' === event.info.code) {
        dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
      }
    }

    private function onNetStatus(event:NetStatusEvent):void {
      if ('NetStream.Play.Start' === event.info.code || 'NetStream.Unpause.Notify' === event.info.code) {
        dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
        return;
      }

      if ('NetStream.Pause.Notify' === event.info.code) {
        dispatchEvent(new ClientEvent(ClientEvent.PAUSED));
        return;
      }
    }
  }
}
