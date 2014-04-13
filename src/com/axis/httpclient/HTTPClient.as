package com.axis.httpclient {
  import com.axis.IClient;
  import com.axis.ClientEvent;

  import flash.media.Video;
  import flash.net.NetConnection;
  import flash.net.NetStream;
  import flash.events.EventDispatcher;

  public class HTTPClient extends EventDispatcher implements IClient {
    private var urlParsed:Object;
    private var video:Video;
    private var ns:NetStream;

    public function HTTPClient(video:Video, urlParsed:Object)
    {
      this.urlParsed = urlParsed;
      this.video = video;
    }

    public function start():Boolean
    {
      trace('HTTPClient: playing:', urlParsed.full);

      var nc:NetConnection = new NetConnection();
      nc.connect(null);

      this.ns = new NetStream(nc);
      dispatchEvent(new ClientEvent(ClientEvent.NETSTREAM_CREATED, { ns : this.ns }));

      this.video.attachNetStream(this.ns);

      ns.play(urlParsed.full);
      return true;
    }

    public function stop():Boolean
    {
      ns.dispose();
      return false;
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
  }
}