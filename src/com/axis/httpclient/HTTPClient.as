package com.axis.httpclient {
  import com.axis.ClientEvent;
  import com.axis.NetStreamClient;
  import com.axis.ErrorManager;
  import com.axis.IClient;
  import com.axis.Logger;

  import flash.utils.*;
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.NetStatusEvent;
  import flash.media.Video;
  import flash.net.NetConnection;
  import flash.net.NetStream;

  public class HTTPClient extends NetStreamClient implements IClient {
    private var urlParsed:Object;
    private var nc:NetConnection;

    private static const FORCED_FPS:Number = 20;
    private static const UPDATE_VIRT_BUFFER_INTERVAL:Number = 1000 / FORCED_FPS;
    private var updateLoop:uint = 0;
    private var virtPause:Boolean = false;
    private var userPause:Boolean = false;
    private var frameByFrame:Boolean = false;
    private var virtBuffer:Number = 0;
    private var streamBuffer:Number = 0;

    public function HTTPClient(urlParsed:Object) {
      this.urlParsed = urlParsed;
    }

    public function start(options:Object):Boolean {
      Logger.log('HTTPClient: playing:', urlParsed.full);

      this.frameByFrame = Player.config.frameByFrame;
      nc = new NetConnection();
      nc.connect(null);
      nc.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);

      this.ns = new NetStream(nc);
      this.setupNetStream();

      this.ns.play(urlParsed.full);
      this.ns.addEventListener(NetStatusEvent.NET_STATUS, this.onNetStreamStatus);
      this.updateLoop = setInterval(this.updateVirtualBuffer, UPDATE_VIRT_BUFFER_INTERVAL);
      return true;
    }

    public function stop():Boolean {
      clearInterval(this.updateLoop);
      this.ns.dispose();
      this.nc.close();
      this.currentState = 'stopped';
      dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
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

      this.userPause = true;
      this.ns.pause();

      if (this.virtPause) {
        dispatchEvent(new ClientEvent(ClientEvent.PAUSED, { 'reason': 'user' }));
      }

      return true;
    }

    public function resume():Boolean {
      if (this.currentState !== 'paused') {
        ErrorManager.dispatchError(801);
        return false;
      }
      this.userPause = false;
      if (!this.virtPause) {
        this.ns.resume();
      } else {
        this.currentState = 'playing';
        dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
      }
      return true;
    }

    public function setFrameByFrame(frameByFrame:Boolean):Boolean {
      this.frameByFrame = frameByFrame;
      return true;
    }

    override public function bufferedTime():Number {
      var c:Number = this.getCurrentTime();
      return c >= 0 ? Math.max(this.virtBuffer - c, 0) : c;
    }

    public function playFrames(timestamp:Number):void {
      if (this.virtBuffer < timestamp) {
        this.virtBuffer = timestamp;
      }
    }

    public function setBuffer(seconds:Number):Boolean {
      this.ns.bufferTime = seconds;
      if (!this.userPause && !this.virtPause) {
        this.ns.pause();
        this.ns.resume();
      }
      return true;
    }

    private function updateVirtualBuffer():void {
      if (this.currentState == 'stopped') {
        return;
      }

      if (this.frameByFrame) {
        var buffer:Number = this.getCurrentTime() + super.bufferedTime();
        var step:Number = 1000 / FORCED_FPS;
        while (this.streamBuffer < buffer) {
          this.streamBuffer = Math.min(this.streamBuffer + step, buffer)
          dispatchEvent(new ClientEvent(ClientEvent.FRAME, this.streamBuffer));
        }
        if (!this.virtPause && this.virtBuffer <= this.getCurrentTime() && !streamEnded) {
          Logger.log('HTTPClient: pause caused by virtual buffer ran out', { currentTime: this.getCurrentTime(), virtualBuffer: this.virtBuffer, realBuffer: super.bufferedTime() });
          this.virtPause = true;
          // Prevent NetStreamClient from triggering paused event
          this.currentState = 'paused';
          this.ns.pause();
        } else if (this.virtPause && this.virtBuffer - this.getCurrentTime() >= this.ns.bufferTime * 1000) {
          this.virtPause = false;
          if (!this.userPause) {
            this.ns.resume();
          }
        }
      } else {
        this.virtBuffer = this.getCurrentTime() + super.bufferedTime();
      }
    }

    private function onNetStreamStatus(event:NetStatusEvent):void {
      if ('NetStream.Play.Stop' === event.info.code) {
        clearInterval(this.updateLoop);
      }
    }

    private function onConnectionStatus(event:NetStatusEvent):void {
      Logger.log('HTTPClient: connection status:', event.info.code);
      if ('NetConnection.Connect.Closed' === event.info.code && this.currentState !== 'stopped') {
        clearInterval(this.updateLoop);
        this.currentState = 'stopped';
        dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
        this.ns.dispose();
      }
    }
  }
}
