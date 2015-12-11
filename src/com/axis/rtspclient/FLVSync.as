package com.axis.rtspclient {
  import flash.events.EventDispatcher;
  import com.axis.Logger;

  public class FLVSync extends EventDispatcher {
    private var videoTags:Array = [];
    private var lastAudioTimestamp:uint = 0;
    /**
     * Let audio tags dictate the sync.
     * All videotags with a timestamp less than or equal to the audio
     * tag timestamp will be dispacted.
     * Video tags are buffered until there is an audio tag available.
     */
    public function onFlvTag(tag:FLVTag):void {
      if (tag.audio) {
        while (videoTags.length > 0 && tag.timestamp >= videoTags[0].timestamp) {
          dispatchEvent(videoTags.shift());
        }

        dispatchEvent(tag.copy())

        while (videoTags.length > 0 && tag.timestamp + tag.duration > videoTags[0].timestamp) {
          dispatchEvent(videoTags.shift());
        }

        this.lastAudioTimestamp = tag.timestamp + tag.duration;
      } else if (tag.timestamp < this.lastAudioTimestamp) {
        dispatchEvent(tag.copy())
      } else {
        videoTags.push(tag.copy());
      }
    }
  }
}
