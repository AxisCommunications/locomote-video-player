# Locomote Video Player [![Build Status](https://travis-ci.org/AxisCommunications/locomote-video-player.svg?branch=master)](https://travis-ci.org/AxisCommunications/locomote-video-player)

## Getting started

### Building Locomote

To compile the project, [nodejs](http://www.nodejs.org) and [npm](http://www.npmjs.org) is required.
Since `npm` is bundled with `nodejs`, you only need to download and install `nodejs`.

To build `Locomote`, simply run `npm install` in the root directory.
This will download [Adobe Flex SDK](http://www.adobe.com/devnet/flex/flex-sdk-download.html),
and other required modules and build the `SWF` file to `build/`.

After `npm` has been installed, `gulp` can also be used to build `Locomote`.

### Building Locomote with Flash Builder
It's also possible to build Locomote with Flash Builder. Follow the steps below to set up a Flash Builder project.

- Clone the Locomote repository from Github.
- Build the project with `npm` as described above. This will build as3corelib and the VERSION file which are both required dependencies.
- Create a new ActionScript project from Flash Builder and save it in the root folder of the cloned repository.
- Inside Flash Builder, right click the `Player.as` file that is now in the `default package` and select "Set as Default Application".
- Remove the `.as` file with the same name you used for the project that was automatically created in `default package`.
- Add as3corelib to the project by selecting "Properties" in the "Project menu" and then "ActionScript Build Path". Click "Add SWC..." and add as3corelib which is located here: `/ext/as3corelib/bin/as3corelib.swc`. Make sure that the library is merged into the code. Please note that the as3corelib.swc file will only be available after you have built the project with `npm`.
- You may need to change the path to the default HTML file in "Run/Debug Settings". Edit the `Player` launch configuration and make sure that the correct url to the HTML file is selected.
- The project can now be built by Flash Builder. Please note that you also need to modify the default HTML template provided with the Flash Builder project to load the swf and Javascript file properly. An example of a minimal HTML file is provided below.

The Flash Builder project files and build folders will be ignored by git automatically so you shouldn't have to add anything to the repository after setting up the project.


### Running Locomote

To run Locomote in a web page, you need to host both the SWF (`Player.swf` in example below),
and the javascript library (`locomote.js` in example below). Use a simple page like:

```html
<html>
  <head>
    <title>Locomote</title>
    <style type="text/css">
      #player {
        width: 320px;
        height: 240px;
      }
    </style>
    <script src="locomote.js"></script>
    <script src="http://code.jquery.com/jquery-2.1.1.min.js"></script>
    <script type="text/javascript">

      $(document).ready(function() {
        /* Instansiate Locomote. First argument is the id of the DOM
           element where Locomote should embed the player. The second
           argument is the URL to the player SWF */
        var locomote = new Locomote('player', 'Player.swf');

        /* Set up a listener for when the API is ready to be used */
        locomote.on('apiReady', function() {
          console.log('API is ready. `play` can now be called');

          /* Tell Locomote to play the specified media */
          locomote.play('rtsp://server.com/stream');
        });

        /* Start listening for streamStarted event */
        locomote.on('streamStarted', function() {
          console.log('stream has started');
        });

        /* If any error occurs, we should take action */
        locomote.on('error', function(err) {
          console.log(err);
        });
      });

    </script>
  </head>
  <body>
    <div id="player" class="player"></div>
  </body>
</html>
```

## API Specification

**NB:** This API is only a draft, and parts of it are not implemented. Do not
use this yet.

### Actions

#### play(url:String)

> Starts playing video from url. Protocol is determined by url.
> Example: `rtsp://server:port/stream`.
>
> Supported protocols:
>
> - `rtsp` - [RTSP over TCP](http://www.ietf.org/rfc/rfc2326.txt)
> - `rtsph` - [RTSP over HTTP](http://www.opensource.apple.com/source/QuickTimeStreamingServer/QuickTimeStreamingServer-412.42/Documentation/RTSP_Over_HTTP.pdf)
> - `rtmp` - [RTMP](http://www.adobe.com/devnet/rtmp.html)
> - `rtmpt` - RTMP over HTTP
> - `rtmps` - RTMP over SSL
> - `http` - Progressive download via HTTP

#### stop()

> Stops video stream.

#### pause()

> Pauses video stream.

#### resume()

> Resumes video from paused state.

#### streamStatus()

> Returns a status object with the following data:

> - fps - frames per second.
> - resolution (object) - the stream size `{ width, height }`.
> - playback speed - current playback speed. 1.0 is normal stream speed.
> - current time - ms from start of stream.
> - protocol - which high-level transport protocol is in use.
> - audio (bool) - if the stream contains audio.
> - video (bool) - if the stream contains video.
> - state - current playback state (playing, paused, stopped).
> - streamURL - the source of the current media.

#### playerStatus()

> Returns a status object with the following data:

> - microphoneVolume - the volume of the microphone when capturing audio
> - speakerVolume - the volume of the speakers (i.e. the stream volume).
> - microphoneMuted (bool) - if the microphone is muted.
> - speakerMuted (bool) - if the speakers are muted.
> - fullScreen (bool) - if the player is currently in fullscreen mode.

#### speakerVolume(vol)

> Sets speaker volume from 0-100. The default value is 50.

#### muteSpeaker()

> Mutes the speaker volume. Remembers the current volume and resets to it if the
> speakers are unmuted.

#### unmuteSpeaker()

> Resets the volume to previous unmuted value.

#### microphoneVolume(vol)

> Sets microphone volume from 0-100. The default value is 50.

#### muteMicrophone()

> Mutes the microphone. Remembers the current volume and resets to it if the
> microphone is unmuted.

#### unmuteMicrophone()

> Resets the volume to previous unmuted value.

#### startAudioTransmit(url, type)

> Starts transmitting microphone input to the camera speaker.
The optional `type` parameter can be used for future implementations of other protocols,
currently only the Axis audio transmit api is supported.
For Axis cameras the `url` parameter should be in the format - `http://server:port/axis-cgi/audio/transmit.cgi`.

#### stopAudioTransmit()

> Stops transmitting microphone input to the camera speaker.

#### config(config)

> Sets configuration values of the player. `config` is a JavaScript object that can have the following optional values:

> - `buffer` - The number of seconds that should be buffered. The default value is `3`.
> - `scaleUp` - Specifies if the video can be scaled up or not. The default value is `false`.
> - `allowFullscreen` - Specifices if fullscreen mode is allowed or not. The default value is `true`.
> - `debugLogger` - Specifices if debug messages should be shown or not. `debugLogger` is an
> which contains `true` or `false` values for `trace` and/or `console`. `true` values will lead
> to information being logged in either the Flash console or in the Javascript console.
> Example `debugLogger: { trace: true, console: false }` causes debug messages to be shown in Flash but not in the Javascript console.
> The default value is `false` for both.

#### on(eventName:String, callback:Function)

> Starts listening for events with `eventName`. Calls `callback` when event triggers.

#### off(eventName:String, callback:Function)

> Stops listening for events with eventName. Calls `callback` when event triggers.

### Events

#### streamStarted

> Dispatched when video streams starts.

#### streamPaused(result)

> Dispatched when video stream is paused. `result` is an object with a single property `reason` that can have the following values:

> - `user` - stream was paused by user.
> - `buffering` - stream has stopped for buffering.

#### streamStopped

> Dispatched when stream stops.

#### streamEnded

> Dispatched when fixed length video stream reaches end of stream. The streamStopped event is also dispatched just before this event.

#### error(error)

> Dispatched when video stream fails. `error` can be either
> protocol error (rtsp etc) or Locomote internal error.
> `error` is a generic object.

> Locomote reports the following types of errors:
> - `RTSP` - The default error codes that are sent from the RTSP stream. Error codes: 100 - 551.
> - `Flash Player` - Errors that are reported by Flash Socket, NetStream and NetConnection classes. Error codes: 700 - 799.
> - `Locomote` - Errors generated by the Locomote player. Error codes: 800 - 899.

> For detailed information about the errors, please see the
[ErrorManager](https://github.com/AxisCommunications/locomote-video-player/blob/master/src/com/axis/ErrorManager.as) class.

#### audioTransmitStarted

> Dispatched when audio transmission starts.

#### audioTransmitStopped

> Dispatched when audio transmission stops.

#### fullscreenEntered

> Dispatched when the player enters fullscreen mode.

#### fullscreenExited

> Dispatched when the player exits fullscreen mode.
