function Locomote(tag, swf) {
  'use strict';

  if (!tag) {
    return null;
  }

  if (!window.LocomoteMap) {
    window.LocomoteMap = {};
  }

  // Instance already initialized. Return it.
  if (window.LocomoteMap[tag]) {
    return window.LocomoteMap[tag];
  }

  // return a new Locomote object if we're in the global scope
  if (this === undefined) {
    window.LocomoteMap[tag] = new Locomote(tag, swf);
    return window.LocomoteMap[tag];
  }

  // Init our element object and return the object
  window.LocomoteMap[tag] = this;
  this.callbacks = [];
  this.swfready = false;
  this.__embed(tag, swf);
  return this;
}

Locomote.prototype = {
  __embed: function(tag, swf) {
    'use strict';

    var guid = (function() {
      function s4() {
        return Math.floor((1 + Math.random()) * 0x10000)
          .toString(16)
          .substring(1);
      }
      return function() {
        return s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4();
      };
    })();
    var tempTag = guid();
    var element =
      '<object type="application/x-shockwave-flash" ' +
      'class="locomote-player" ' +
      'data="' + swf + '" ' +
      'id="' + tempTag + '" ' +
      'name="' + tag + '" ' +
      'width="100%" ' +
      'height="100%" ' +
      'allowFullScreen="true"';

    // Default Flash Player options
    var opts = {
      width: '100%',
      height: '100%',
      allowscriptaccess: 'always',
      wmode: 'transparent',
      quality: 'high',
      flashvars: '',
      movie: swf,
      name: tag
    };

    for (var index in opts) {
      if (opts.hasOwnProperty(index)) {
        element += '<param name="' + index + '" value="' + opts[index] + '"/>';
      }
    }

    element += '</object>';

    // Insert the object into the provided tag
    document.getElementById(tag).innerHTML = element;

    // Save the reference to the Flash Player object
    this.e = document.getElementById(tempTag);
  },

  __swfReady: function() {
    'use strict';

    this.swfready = true;
    this.__playerEvent('apiReady');
  },

  play: function(url) {
    'use strict';

    this.e.play(url);
    return this;
  },

  stop: function() {
    'use strict';

    this.e.stop();
    return this;
  },

  pause: function() {
    'use strict';

    this.e.pause();
    return this;
  },

  resume: function() {
    'use strict';

    this.e.resume();
    return this;
  },

  seek: function(timestamp) {
    'use strict';

    console.log('seek, timestamp->' + timestamp);
  },

  playbackSpeed: function(speed) {
    'use strict';

    console.log('playbackSpeed, speed->' + speed);
  },

  streamStatus: function() {
    'use strict';

    return this.e.streamStatus();
  },

  playerStatus: function() {
    'use strict';

    return this.e.playerStatus();
  },

  speakerVolume: function(volume) {
    'use strict';

    this.e.speakerVolume(volume);
    return this;
  },

  muteSpeaker: function() {
    'use strict';

    this.e.muteSpeaker();
    return this;
  },

  unmuteSpeaker: function() {
    'use strict';

    this.e.unmuteSpeaker();
    return this;
  },

  microphoneVolume: function(volume) {
    'use strict';

    this.e.microphoneVolume(volume);
    return this;
  },

  muteMicrophone: function() {
    'use strict';

    this.e.muteMicrophone();
    return this;
  },

  unmuteMicrophone: function() {
    'use strict';

    this.e.unmuteMicrophone();
    return this;
  },

  startAudioTransmit: function(url, type) {
    'use strict';

    this.e.startAudioTransmit(url, type || 'axis');
    return this;
  },

  stopAudioTransmit: function() {
    'use strict';

    this.e.stopAudioTransmit();
    return this;
  },

  config: function(config) {
    'use strict';

    this.e.setConfig(config);
  },

  on: function(eventName, callback) {
    'use strict';

    this.callbacks.push({ eventName: eventName, callback: callback });

    if (eventName === 'apiReady' && this.swfready) {
      callback.call();
    }
  },

  off: function(eventName, callback) {
    'use strict';

    this.callbacks.forEach(function(element, index, array) {
      if ((element.eventName === eventName) && (element.callback === callback)) {
        array.splice(index, 1);
      }
    });
  },

  __playerEvent: function(eventName) {
    'use strict';

    this.callbacks.forEach(function(element, index, array) {
      if (element.eventName === eventName && element.callback) {
        element.callback.call();
      }
    });
  },
};
