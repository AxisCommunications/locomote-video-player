package com.axis.rtspclient {
  import com.axis.rtspclient.ByteArrayUtils;
  import com.axis.rtspclient.RTP;

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;

  /* Assembler of PCMA frames */
  public class APCMA extends EventDispatcher {
    private var sdp:SDP;

    public function APCMA() {}

    public function onRTPPacket(pkt:RTP):void {
      dispatchEvent(new PCMAFrame(pkt.getPayload(), pkt.getTimestampMS()));
    }
  }
}
