package com.axis.rtspclient {

  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

  public class RTP {

    private var data:ByteArray;
    private var jsEventCallbackName:String;

    private var version:uint;
    private var padding:uint;
    private var extension:uint;
    private var csrc:uint;
    private var marker:uint;
    private var pt:uint;
    private var sequence:uint;
    private var timestamp:uint;

    public function RTP(pkg:ByteArray, jsEventCallbackName:String)
    {
      var line1:uint = pkg.readUnsignedInt();

      version   = (line1 & 0xC0000000) >>> 30;
      padding   = (line1 & 0x20000000) >>> 29;
      extension = (line1 & 0x10000000) >>> 28;
      csrc      = (line1 & 0x0F000000) >>> 24;
      marker    = (line1 & 0x00800000) >>> 23;
      pt        = (line1 & 0x007F0000) >>> 16;
      sequence  = (line1 & 0x0000FFFF) >>> 0;
      timestamp = pkg.readUnsignedInt();

      ExternalInterface.call(jsEventCallbackName, "version:   " + version);
      ExternalInterface.call(jsEventCallbackName, "padding:   " + padding);
      ExternalInterface.call(jsEventCallbackName, "extension: " + extension);
      ExternalInterface.call(jsEventCallbackName, "csrc:      " + csrc);
      ExternalInterface.call(jsEventCallbackName, "marker:    " + marker);
      ExternalInterface.call(jsEventCallbackName, "pt:        " + pt);
      ExternalInterface.call(jsEventCallbackName, "sequence:  " + sequence);
      ExternalInterface.call(jsEventCallbackName, "timestamp: " + timestamp);

      this.data                = data;
      this.jsEventCallbackName = jsEventCallbackName;
    }
  }
}

