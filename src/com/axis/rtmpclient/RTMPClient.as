package com.axis.rtmpclient {
  import flash.net.NetStream;
  import flash.net.NetConnection;
  import flash.media.Video;
  import flash.events.EventDispatcher;
  import flash.events.NetStatusEvent;
  import flash.events.AsyncErrorEvent;
  import com.axis.IClient;
  import com.axis.ClientEvent;

  public class RTMPClient extends EventDispatcher implements IClient {

    private var video:Video;
    private var urlParsed:Object;
    private var nc:NetConnection;
    private var ns:NetStream;
    private var streamServer:String;
    private var streamId:String;

    public function RTMPClient(video:Video, urlParsed:Object)
    {
      this.video = video;
      this.urlParsed = urlParsed;
    }

    public function start():Boolean
    {
      this.nc = new NetConnection();
      nc.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
      nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
      nc.client = this;


      this.streamId = urlParsed.basename;
      this.streamServer = urlParsed.protocol + '://' + urlParsed.host + urlParsed.basepath;

      nc.connect(streamServer);

      return true;
    }

    public function stop():Boolean
    {
      ns.dispose();
      return true;
    }

    public function pause():Boolean
    {
      ns.pause();
      return true;
    }

    public function resume():Boolean
    {
      ns.resume();
      return true;
    }

    private function onConnectionStatus(event:NetStatusEvent):void
    {
      trace('RTMPClient: Connection status:', event.info.code);
      if ('NetConnection.Connect.Success' === event.info.code) {
        this.ns = new NetStream(this.nc);
        dispatchEvent(new ClientEvent(ClientEvent.NETSTREAM_CREATED, { ns : this.ns }));
        this.video.attachNetStream(this.ns);
        this.ns.play(this.streamId);
      }
    }

    private function asyncErrorHandler(event:AsyncErrorEvent):void
    {
      trace('RTMPClient: Async Error Event:', event.error);
    }

    public function onBWDone():void
    {
      /* Why is this enforced by NetConnection? */
    }

    public function onFCSubscribe(info:Object):void
    {
    }
  }
}

