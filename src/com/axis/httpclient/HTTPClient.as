package com.axis.httpclient {
  import com.axis.IClient;

  import flash.net.NetStream;

  public class HTTPClient implements IClient {
    private var urlParsed:Object;
    private var ns:NetStream;

    public function HTTPClient(ns:NetStream, urlParsed:Object) {
      this.urlParsed = urlParsed;
      this.ns = ns;
    }

    public function start():Boolean
    {
      ns.play(urlParsed.full);
      return true;
    }

    public function stop():Boolean
    {
      ns.close();
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