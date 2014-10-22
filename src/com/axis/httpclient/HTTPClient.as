package com.axis.httpclient {
  import com.axis.ClientEvent;
  import com.axis.ErrorManager;
  import com.axis.IClient;
  import com.axis.Logger;

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
    public var ended:Boolean = false;
    private var currentState:String = 'stopped';

    public function HTTPClient(video:Video, urlParsed:Object) {
      this.urlParsed = urlParsed;
      this.video = video;
    }

    public function start():Boolean {
      Logger.log('HTTPClient: playing:' + urlParsed.full);

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
      this.currentState = 'stopped';
      return true;
    }

    public function seek(position:Number):Boolean {
      ns.seek(position);
      return true;
    }

    public function pause():Boolean {
      if (this.currentState !== 'playing') {
        ErrorManager.dispatchError(800);
        return false;
      }
      ns.pause();
      return true;
    }

    public function resume():Boolean {
      if (this.currentState !== 'paused') {
        ErrorManager.dispatchError(801);
        return false;
      }
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
        this.currentState = 'stopped';
        dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
      }
    }

    private function onNetStatus(event:NetStatusEvent):void {
      if ('NetStream.Play.Start' === event.info.code || 'NetStream.Unpause.Notify' === event.info.code) {
        this.currentState = 'playing';
        dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
        return;
      }

      if ('NetStream.Play.Stop' === event.info.code) {
        ended = true;
        return;
      }

      if (!ended && 'NetStream.Buffer.Empty' === event.info.code) {
        this.currentState = 'paused';
        dispatchEvent(new ClientEvent(ClientEvent.PAUSED, { 'reason': 'buffering' }));
        return;
      }

      if ('NetStream.Pause.Notify' === event.info.code) {
        this.currentState = 'paused';
        dispatchEvent(new ClientEvent(ClientEvent.PAUSED, { 'reason': 'user' }));
        return;
      }
    }
  }
}
