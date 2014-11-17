package com.axis {
  import flash.events.EventDispatcher;
  import flash.events.AsyncErrorEvent;
  import flash.events.DRMErrorEvent;
  import flash.events.IOErrorEvent;
  import flash.events.NetStatusEvent;
  import flash.net.NetStream;

  import mx.utils.ObjectUtil;

  public class NetStreamClient extends EventDispatcher {
    public var onXMPData:Function = null;
    public var onCuePoint:Function = null;
    public var onImageData:Function = null;
    public var onSeekPoint:Function = null;
    public var onTextData:Function = null;

    private var ended:Boolean = false;
    protected var ns:NetStream;
    protected var currentState:String = 'stopped';

    public function hasVideo():Boolean {
      Logger.log(this.ns.info);
      return (0 < this.ns.info.videoBufferByteLength);
    };

    public function hasAudio():Boolean {
      return (0 < this.ns.info.audioBufferByteLength);
    };

    public function currentFPS():Number {
      return Math.floor(this.ns.currentFPS + 0.5);
    };

    protected function setupNetStream():void {
      this.ns.bufferTime = Player.config.buffer;
      this.ns.client = this;
      this.onXMPData = onXMPDataHandler;
      this.onCuePoint = onCuePointHandler;
      this.onImageData = onImageDataHandler;
      this.onSeekPoint = onSeekPointHandler;
      this.onTextData = onTextDataHandler;
      this.ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
      this.ns.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
      this.ns.addEventListener(DRMErrorEvent.DRM_ERROR, onDRMError);
      this.ns.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
    }

    public function onXMPDataHandler(xmpData:Object):void {
      Logger.log('XMPData received->' + xmpData.data);
    }

    public function onCuePointHandler(cuePoint:Object):void {
      Logger.log('CuePoint received: ' + cuePoint.name);
    }

    public function onImageDataHandler(imageData:Object):void {
      Logger.log('ImageData received');
    }

    public function onSeekPointHandler(seekPoint:Object):void {
      Logger.log('SeekPoint received');
    }

    public function onTextDataHandler(textData:Object):void {
      Logger.log('TextData received');
    }

    private function onAsyncError(event:AsyncErrorEvent):void {
      ErrorManager.dispatchError(725, [event.error.message]);
    }

    private function onDRMError(event:DRMErrorEvent):void {
      ErrorManager.dispatchError(726, [event.errorID, event.subErrorID]);
    }

    private function onIOError(event:IOErrorEvent):void {
      ErrorManager.dispatchError(727, [event.text]);
    }

    public function onMetaData(item:Object):void {
      Logger.log('Netstream Metadata:', ObjectUtil.toString(item));

      dispatchEvent(new ClientEvent(ClientEvent.META, {
        'width': item.width,
        'height': item.height
      }));
    }

    public function onPlayStatus(event:Object):void {
      Logger.log('onPlayStatus:', event.code);
    }

    private function onNetStatus(event:NetStatusEvent):void {
      Logger.log('NetStream status:', event.info.code);

      if (this.ns.bufferTime === 0 && ('NetStream.Play.Start' === event.info.code || 'NetStream.Unpause.Notify' === event.info.code)) {
        this.currentState = 'playing';
        dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
        return;
      }

      if ('NetStream.Play.Stop' === event.info.code) {
        dispatchEvent(new ClientEvent(ClientEvent.STOPPED));
        ended = true;
        return;
      }

      if (!ended && 'NetStream.Buffer.Empty' === event.info.code) {
        this.currentState = 'paused';
        dispatchEvent(new ClientEvent(ClientEvent.PAUSED, { 'reason': 'buffering' }));
        return;
      }

      if ('NetStream.Buffer.Full' === event.info.code) {
        this.currentState = 'playing';
        dispatchEvent(new ClientEvent(ClientEvent.START_PLAY));
        return;
      }

      if ('NetStream.Pause.Notify' === event.info.code) {
        this.currentState = 'paused';
        dispatchEvent(new ClientEvent(ClientEvent.PAUSED, { 'reason': 'user' }));
        return;
      }

      if (event.info.status === 'error' || event.info.level === 'error')  {
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
