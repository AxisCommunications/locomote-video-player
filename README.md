Getting started
==================

  * Download [Adobe Flex SDK](http://www.adobe.com/devnet/flex/flex-sdk-download.html).
  * Extract it to some location.
  * In `Locomote` folder, run `FLEX_HOME=<path to flex> make`.
  * `Player.swf` should now be available in the `build` folder.


Locomote API Specification
==========================

Actions
=======

play(url:String)
---------------------
Starts playing video from url. Protocol is determined by url - rtsp://server:port/stream etc.

Supported protocols:

- rtrsp
- rtsph
- rtmp, rtmpt, rtmps
- http

stop()
--------
Stops video stream.

pause()
-----------
Pauses video stream.

resume()
-------------
Resumes video from paused state.

seek(timestamp)
------------------------
Seeks for timestamp in video stream. The current stream state is preserved - paused or playing. timestamp = ms from start of stream.

playbackSpeed(speed)
---------------------------------
Fast forward video stream with speed.

streamStatus()
---------------------
Returns a status object with the following data:

- fps
- resolution
- playback speed
- current time (ms from start of stream)
- protocol
- audio (bool)
- video (bool)
- state (playing, paused, stopped)
- isSeekable (bool)
- isPlaybackSpeedChangeable (bool)
- streamURL

playerStatus()
-------------------
Returns a status object with the following data:

- audio (bool)
- video (bool)
- microphoneVolume
- speakerVolume
- microphoneMuted (bool)
- speakerMuted (bool)
- fullScreen (bool)

speakerVolume(vol=0.5)
-----------------------------------
Set video players volume from 0-1. Default value is 0.5.

muteSpeaker()
---------------------
Mutes the volume.

unmuteSpeaker()
-------------------------
Resets the volume to previous unmuted value.

microphoneVolume(vol=0.5)
-----------------------------------------
Set video players volume from 0-1. Default value is 0.5.

muteMicrophone()
---------------------------
Mutes the volume.

unmuteMicrophone()
-------------------------------
Resets the volume to previous unmuted value.

setFullScreenAllowed(state)
----------------------------------------
Sets if full screen mode by double clicking the player is allowed or not.

on(eventName:String, callback:Function)
------------------------
Starts listening for events with eventName.

off(eventName:String, callback:Function)
------------------------
Stops listening for events with eventName.

Events
=====
streamStarted
--------------------
Dispatched when video streams starts.

streamStopped
----------------------
Dispatched when stream stops.

streamError(errorCode, error)
------------------------------------------
Dispatched when video stream fails. Error code and message can be either protocol error code (rtsp etc) or Locomote internal error code. Includes socket and seek errors. error is a generic object.

streamPaused(reason)
--------------------------------
Dispatched when video stream is paused. reason can have the following values:

- user (stream was paused by user)
- buffering (stream has stopped for buffering)

streamResumed
-----------------------
Dispatched when stream playing is resumed after pause.

seekCompleted
-----------------------
Dispatched when seek has completed.

streamEnded
-------------------
Dispatched when fixed length video stream reaches end of stream.

fullScreenEntered
-------------------------
Dispatched when the player enters fullscreen mode.

fullScreenExited
-----------------------
Dispatched when the player exits fullscreen mode.