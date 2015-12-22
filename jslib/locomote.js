(function(root, factory) {
  'use strict';

  if (typeof exports == 'object') {
    /* CommonJS */
    module.exports = factory();
  } else if (typeof define == 'function' && define.amd) {
    /* AMD module */
    define(factory);
  } else {
    /* Browser global */
    root.Locomote = factory();
  }
}
(this, function() {
  'use strict';

  function Locomote(tag, swf) {
    if (!tag) {
      return null;
    }

    if (!window.LocomoteMap) {
      window.LocomoteMap = {};
    }

    // Instance already initialized. Return it.
    if (window.LocomoteMap[tag] &&
        window.LocomoteMap[tag].swfready) {
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
      this.tag = tag;

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
        'allowFullScreen="true">';

      // Default Flash Player options
      var opts = {
        width: '100%',
        height: '100%',
        allowscriptaccess: 'always',
        wmode: 'transparent',
        quality: 'high',
        flashvars: 'locomoteID=' + tag,
        allowFullScreenInteractive: true,
        movie: swf,
        name: tag
      };

      for (var index in opts) {
        if (opts.hasOwnProperty(index)) {
          element += '<param name="' + index + '" value="' + opts[index] + '"/>';
        }
      }

      element += '</object>';

      if (('string' === typeof tag) && document.getElementById(tag)) {
        // Insert the object into the provided tag
        document.getElementById(tag).innerHTML = element;

        // Save the reference to the Flash Player object
        this.e = document.getElementById(tempTag);
      } else {
        // Insert the object into the provided element
        tag.innerHTML = element;

        // Save the reference to the Flash Player object
        var players = tag.getElementsByClassName('locomote-player');

        for (var i = 0; i < players.length; i++) {
          if (players[i].getAttribute('id') === tempTag) {
            this.e = players[i];
            break;
          }
        }
      }
    },

    __swfReady: function() {
      this.swfready = true;
      this.__playerEvent('apiReady');
    },

    play: function(url, options) {
      options = options || {};
      this.e.play(url, options);
      return this;
    },

    stop: function() {
      this.e.stop();
      return this;
    },

    seek: function(position) {
      this.e.seek(position);
      return this;
    },

    pause: function() {
      this.e.pause();
      return this;
    },

    resume: function() {
      this.e.resume();
      return this;
    },

    playFrames: function(timestamp) {
      this.e.playFrames(timestamp);
      return this;
    },

    streamStatus: function() {
      return this.e.streamStatus();
    },

    playerStatus: function() {
      return this.e.playerStatus();
    },

    speakerVolume: function(volume) {
      this.e.speakerVolume(volume);
      return this;
    },

    muteSpeaker: function() {
      this.e.muteSpeaker();
      return this;
    },

    unmuteSpeaker: function() {
      this.e.unmuteSpeaker();
      return this;
    },

    microphoneVolume: function(volume) {
      this.e.microphoneVolume(volume);
      return this;
    },

    muteMicrophone: function() {
      this.e.muteMicrophone();
      return this;
    },

    unmuteMicrophone: function() {
      this.e.unmuteMicrophone();
      return this;
    },

    startAudioTransmit: function(url, type) {
      this.e.startAudioTransmit(url, type || 'axis');
      return this;
    },

    stopAudioTransmit: function() {
      this.e.stopAudioTransmit();
      return this;
    },

    config: function(config) {
      this.e.setConfig(config);
      return this;
    },

    loadPolicyFile: function(url) {
      this.e.loadPolicyFile(url);
      return this;
    },

    on: function(eventName, callback) {
      this.callbacks.push({ eventName: eventName, callback: callback });

      if (eventName === 'apiReady' && this.swfready) {
        callback.call();
      }
      return this;
    },

    off: function(eventName, callback) {
      if (!eventName && !callback) {
        this.callbacks = [];
        return this;
      }

      this.callbacks.forEach(function(element, index, array) {
        if (element.callback === callback) {
          if (!eventName || (element.eventName === eventName)) {
            array.splice(index, 1);
            return this;
          }
        }

        if (element.eventName === eventName) {
          if (!callback || (element.callback === callback)) {
            array.splice(index, 1);
          }
        }
      });
      return this;
    },

    __playerEvent: function(eventName /* ... args */) {
      var params = [];
      params.push.apply(params, arguments);
      params.shift(); /* First element is event name */
      this.callbacks.forEach(function(element, index, array) {
        if (element.eventName === eventName && element.callback) {
          element.callback.apply(null, params);
        }
      });
    },

    destroy: function() {
      window.LocomoteMap[this.tag] = {
        __playerEvent: function () {},
        __swfReady: function () {}
      };
      typeof this.e.stop === 'function' && this.e.stop();
      this.e.parentNode.removeChild(this.e);
      this.e = null;
    }
  };

  return Locomote;
}));
