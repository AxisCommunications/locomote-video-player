package com.axis.httpclient {
  import com.axis.ClientEvent;
  import com.axis.NetStreamClient;
  import com.axis.ErrorManager;
  import com.axis.IClient;
  import com.axis.Logger;

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.NetStatusEvent;
  import flash.media.Video;
  import flash.net.NetConnection;
  import flash.net.NetStream;

  public class HTTPClient extends NetStreamClient implements IClient {
    private var urlParsed:Object;
    private var nc:NetConnection;

    public function HTTPClient(urlParsed:Object) {
      this.urlParsed = urlParsed;
    }

    public function start():Boolean {
      Logger.log('HTTPClient: playing:', urlParsed.full);

      nc = new NetConnection();
      nc.connect(null);
      nc.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);

      this.ns = new NetStream(nc);
      this.setupNetStream();

      this.ns.play(urlParsed.full);
      return true;
    }

    public function stop():Boolean {
      this.ns.dispose();
      this.nc.close();
      this.currentState = 'stopped';
      return true;
    }

    public function seek(position:Number):Boolean {
      this.ns.seek(position);
      return true;
    }

    public function pause():Boolean {
      if (this.currentState !== 'playing') {
        ErrorManager.dispatchError(800);
        return false;
      }
      this.ns.pause();
      return true;
    }

    public function resume():Boolean {
      if (this.currentState !== 'paused') {
        ErrorManager.dispatchError(801);
        return false;
      }
      this.ns.resume();
      return true;
    }

    public function setBuffer(seconds:Number):Boolean {
      this.ns.bufferTime = seconds;
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
  }
}
