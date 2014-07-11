# Locomote Video Player

## Getting started

  * Download [Adobe Flex SDK](http://www.adobe.com/devnet/flex/flex-sdk-download.html).
  * Extract it to some location.
  * In `Locomote` folder, run `FLEX_HOME=<path to flex> make`.
  * `Player.swf` should now be available in the `build` folder.


## API Specification

**NB:** This API is only a draft, and parts of it are not implemented. Do not
use this yet.

### Actions

#### play(url:String)

Starts playing video from url. Protocol is determined by url.
Example: `rtsp://server:port/stream`.

Supported protocols:

- `rtsp` - [RTSP over TCP](http://www.ietf.org/rfc/rfc2326.txt)
- `rtsph` - [RTSP over HTTP](http://www.opensource.apple.com/source/QuickTimeStreamingServer/QuickTimeStreamingServer-412.42/Documentation/RTSP_Over_HTTP.pdf)
- `rtmp` - [RTMP](http://www.adobe.com/devnet/rtmp.html)
- `rtmpt` - RTMP over HTTP
- `rtmps` - RTMP over SSL
- `http` - Progressive download via HTTP

#### stop()

Stops video stream.

#### pause()

Pauses video stream.

#### resume()

Resumes video from paused state.

#### seek(timestamp)

Seeks to `timestamp` ms from  start of stream.
The current stream state is preserved - paused or playing.

#### playbackSpeed(speed)

Fast forward video stream with playback speed multiplied with `speed`.

#### streamStatus()

Returns a status object with the following data:

- fps - frames per second.
- resolution - the stream size `WIDTHxHEIGHT`.
- playback speed - current playback speed. 1.0 is normal stream speed.
- current time - ms from start of stream.
- protocol - which high-level transport protocol is in use.
- audio (bool) - if the stream contains audio.
- video (bool) - if the stream contains video.
- state - current playback state (playing, paused, stopped).
- isSeekable (bool) - if it is possible to seek in the stream.
- isPlaybackSpeedChangeable (bool) - if the playback speed can be altered.
- streamURL - the source of the current media.

#### playerStatus()

Returns a status object with the following data:

- microphoneVolume - the volume of the microphone when capturing audio
- speakerVolume - the volume of the speakers (i.e. the stream volume).
- microphoneMuted (bool) - if the microphone is muted.
- speakerMuted (bool) - if the speakers are muted.
- fullScreen (bool) - if the player is currently in fullscreen mode.

#### speakerVolume(vol=0.5)

Set video players volume from 0-1. Default value is 0.5.

#### muteSpeaker()

Mutes the volume. This remembers the current volume and resets to it if the
speakers are unmuted.

#### unmuteSpeaker()

Resets the volume to previous unmuted value.

#### microphoneVolume(vol=0.5)

Set video players volume from 0-1. Default value is 0.5.

#### muteMicrophone()

Mutes the volume. This remembers the current volume and resets to it if the
microphone is unmuted.

#### unmuteMicrophone()

Resets the volume to previous unmuted value.

#### allowFullscreen(state)

Sets if full screen mode by double clicking the player is allowed or not.

#### on(eventName:String, callback:Function)

Starts listening for events with `eventName`. Calls `callback` when event triggers.

#### off(eventName:String, callback:Function)

Stops listening for events with eventName. Calls `callback` when event triggers.

### Events

#### streamStarted

Dispatched when video streams starts.

#### streamStopped

Dispatched when stream stops.

#### streamError(error)

Dispatched when video stream fails. `error` can be either
protocol error (rtsp etc) or Locomote internal error.
Includes socket and seek errors.`error` is a generic object.

#### streamPaused(reason)

Dispatched when video stream is paused. `reason` can have the following values:

- `user` - stream was paused by user.
- `buffering` - stream has stopped for buffering.

#### streamResumed

Dispatched when stream playing is resumed after pause.

#### seekCompleted

Dispatched when seek has completed.

#### streamEnded

Dispatched when fixed length video stream reaches end of stream.

#### fullScreenEntered

Dispatched when the player enters fullscreen mode.

#### fullScreenExited

Dispatched when the player exits fullscreen mode.
