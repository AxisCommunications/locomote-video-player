package com.axis.rtmpclient {
  import com.axis.ClientEvent;
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

  public class RTMPClient extends EventDispatcher implements IClient {
    private var video:Video;
    private var urlParsed:Object;
    private var nc:NetConnection;
    private var ns:NetStream;
    private var streamServer:String;
    private var streamId:String;
    private var currentState:String = 'stopped';

    public function RTMPClient(video:Video, urlParsed:Object) {
      this.video = video;
      this.urlParsed = urlParsed;
    }

    public function start():Boolean {
      this.nc = new NetConnection();
      nc.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
      nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
      nc.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
      nc.addEventListener(NetStatusEvent.NET_STATUS, onNetStatusError);
      nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
      nc.client = this;

      this.streamId = urlParsed.basename;
      this.streamServer  = urlParsed.protocol + '://';
      this.streamServer += urlParsed.host;
      this.streamServer += ((urlParsed.portDefined) ? (':' + urlParsed.port) : '')
      this.streamServer += urlParsed.basepath;
      Logger.log(this.streamServer);

      Logger.log('RTMPClient: connecting to server: \'' + streamServer + '\'');
      nc.connect(streamServer);

      return true;
    }

    public function stop():Boolean {
      ns.dispose();
      nc.close();
      this.currentState = 'stopped';
      return true;
    }

    public function pause():Boolean {
      if (this.currentState !== 'playing') {
        ErrorManager.dispatchError(800);
        return false;
      }
      ns.pause();
      this.currentState = 'paused';
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

    private function onConnectionStatus(event:NetStatusEvent):void {
      if ('NetConnection.Connect.Success' === event.info.code) {
        Logger.log('RTMPClient: connected');
        this.ns = new NetStream(this.nc);
        dispatchEvent(new ClientEvent(ClientEvent.NETSTREAM_CREATED, { ns : this.ns }));
        this.ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
        this.video.attachNetStream(this.ns);
        Logger.log('RTMPClient: starting stream: \'' + this.streamId + '\'');
        this.ns.play(this.streamId);
      }

      if ('NetConnection.Connect.Closed' === event.info.code) {
        dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
        this.currentState = 'stopped';
      }
    }

    private function asyncErrorHandler(event:AsyncErrorEvent):void {
      Logger.log('RTMPClient: Async Error Event:' + event.error);
    }

    public function onBWDone(arg:*):void {
      /* Why is this enforced by NetConnection? */
    }

    public function onFCSubscribe(info:Object):void {
    }

    public function forceBuffering():Boolean {
      ns.pause();
      ns.resume();
      return true;
    }

    private function onNetStatus(event:NetStatusEvent):void {
      if (this.ns.bufferTime === 0 && 'NetStream.Play.Start' === event.info.code) {
        // Buffer is set to 0, dispatch start event immediately
        dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
        this.currentState = 'playing';
        return;
      }

      if (this.ns.bufferTime === 0 && 'NetStream.Unpause.Notify' === event.info.code) {
        // Buffer is set to 0, dispatch start event immediately
        dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
        this.currentState = 'playing';
        return;
      }

      if ('NetStream.Buffer.Full' === event.info.code) {
        dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
        this.currentState = 'playing';
        return;
      }

      if ('NetStream.Buffer.Empty' === event.info.code) {
        dispatchEvent(new ClientEvent(ClientEvent.PAUSED, { 'reason': 'buffering' }));
        this.currentState = 'paused';
        return;
      }

      if ('NetStream.Pause.Notify' === event.info.code) {
        dispatchEvent(new ClientEvent(ClientEvent.PAUSED, { 'reason': 'user' }));
        this.currentState = 'paused';
        return;
      }
    }

    private function onIOError(event:IOErrorEvent):void {
      ErrorManager.dispatchError(729, [event.text]);
    }

    private function onSecurityError(event:SecurityErrorEvent):void {
      ErrorManager.dispatchError(730, [event.text]);
    }

    private function onNetStatusError(event:NetStatusEvent):void {
      if (event.info.status === 'error') {
        var errorCode:int = 0;
        switch (event.info.code) {
        case 'NetConnection.Call.BadVersion':       errorCode = 700; break;
        case 'NetConnection.Call.Failed':           errorCode = 701; break;
        case 'NetConnection.Call.Prohibited':       errorCode = 702; break;
        case 'NetConnection.Connect.AppShutdown':   errorCode = 703; break;
        case 'NetConnection.Connect.Failed':        errorCode = 704; break;
        case 'NetConnection.Connect.InvalidApp':    errorCode = 705; break;
        case 'NetConnection.Connect.Rejected':      errorCode = 706; break;
        case 'NetGroup.Connect.Failed':             errorCode = 707; break;
        case 'NetGroup.Connect.Rejected':           errorCode = 708; break;
        case 'NetStream.Connect.Failed':            errorCode = 709; break;
        case 'NetStream.Connect.Rejected':          errorCode = 710; break;
        case 'NetStream.Failed':                    errorCode = 711; break;
        case 'NetStream.Play.Failed':               errorCode = 712; break;
        case 'NetStream.Play.FileStructureInvalid': errorCode = 713; break;
        case 'NetStream.Play.InsufficientBW':       errorCode = 714; break;
        case 'NetStream.Play.StreamNotFound':       errorCode = 715; break;
        case 'NetStream.Publish.BadName':           errorCode = 716; break;
        case 'NetStream.Record.Failed':             errorCode = 717; break;
        case 'NetStream.Record.NoAccess':           errorCode = 718; break;
        case 'NetStream.Seek.Failed':               errorCode = 719; break;
        case 'NetStream.Seek.InvalidTime':          errorCode = 720; break;
        case 'SharedObject.BadPersistence':         errorCode = 721; break;
        case 'SharedObject.Flush.Failed':           errorCode = 722; break;
        case 'SharedObject.UriMismatch':            errorCode = 723; break;

        default:
          ErrorManager.dispatchError(724, [event.info.code]);
          return;
        }

        if (errorCode) {
          ErrorManager.dispatchError(errorCode);
        }
      }
    }
  }
}
