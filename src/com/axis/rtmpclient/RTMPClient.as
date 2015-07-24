package com.axis.rtmpclient {
  import com.axis.ClientEvent;
  import com.axis.NetStreamClient;
  import com.axis.ErrorManager;
  import com.axis.IClient;
  import com.axis.Logger;

  import flash.events.AsyncErrorEvent;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.events.NetStatusEvent;
  import flash.events.SecurityErrorEvent;
  import flash.media.Video;
  import flash.net.NetConnection;
  import flash.net.NetStream;

  public class RTMPClient extends NetStreamClient implements IClient {
    private var urlParsed:Object;
    private var nc:NetConnection;
    private var streamServer:String;
    private var streamId:String;

    public function RTMPClient(urlParsed:Object) {
      this.urlParsed = urlParsed;
    }

    public function start(options:Object):Boolean {
      this.nc = new NetConnection();
      this.nc.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
      this.nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
      this.nc.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
      this.nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
      this.nc.client = this;

      if (urlParsed.hasOwnProperty("connect") && urlParsed.hasOwnProperty("streamName")) {
        this.streamId = urlParsed.streamName;
        this.streamServer = urlParsed.connect;
      } else {
        this.streamId = urlParsed.basename;
        this.streamServer  = urlParsed.protocol + '://';
        this.streamServer += urlParsed.host;
        this.streamServer += ((urlParsed.portDefined) ? (':' + urlParsed.port) : '')
        this.streamServer += urlParsed.basepath;
      }

      Logger.log('RTMPClient: connecting to server: \'' + streamServer + '\'');
      this.nc.connect(streamServer);

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
      this.currentState = 'paused';
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

    public function setFrameByFrame(frameByFrame:Boolean):Boolean {
      return false;
    }

    public function playFrames(timestamp:Number):void {}

    public function setBuffer(seconds:Number):Boolean {
      this.ns.bufferTime = seconds;
      this.ns.pause();
      this.ns.resume();
      return true;
    }

    private function onConnectionStatus(event:NetStatusEvent):void {
      if ('NetConnection.Connect.Success' === event.info.code) {
        Logger.log('RTMPClient: connected');
        this.ns = new NetStream(this.nc);
        this.setupNetStream();

        Logger.log('RTMPClient: starting stream: \'' + this.streamId + '\'');
        this.ns.play(this.streamId);
      }

      if ('NetConnection.Connect.Closed' === event.info.code) {
        this.currentState = 'stopped';
        dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
      }
    }

    private function asyncErrorHandler(event:AsyncErrorEvent):void {
      Logger.log('RTMPClient: Async Error Event:' + event.error);
    }

    public function onBWDone(arg:*):void {
      /* Why is this enforced by NetConnection? */
    }

    public function onFCSubscribe(info:Object):void {
      /* Why is this enforced by NetConnection? */
    }

    private function onIOError(event:IOErrorEvent):void {
      ErrorManager.dispatchError(729, [event.text]);
    }

    private function onSecurityError(event:SecurityErrorEvent):void {
      ErrorManager.dispatchError(730, [event.text]);
    }
  }
}
