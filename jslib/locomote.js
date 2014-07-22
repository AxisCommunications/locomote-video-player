function Locomote(tag, swf) {
  this.callbacks = [];
  this.swfready = false;

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
  if (window === this) {
    window.LocomoteMap[tag] = new Locomote(tag, swf);
    return window.LocomoteMap[tag];
  }

  // Init our element object and return the object
  window.LocomoteMap[tag] = this;
  this.__embed(tag, swf);
  return this;
}

Locomote.prototype = {
  __embed: function(tag, swf) {
    var tempTag = 'player_' + (new Date()).getTime();
    element = '<object type="application/x-shockwave-flash" ';
    element += 'class="locomote-player" ';
    element += 'data="' + swf + '" ';
    element += 'id="' + tempTag + '" ';
    element += 'name="' + tag + '" ';
    element += 'width="100%" ';
    element += 'height="100%" ';
    element += 'allowFullScreen="true"';

    // Default Flash Player options
    var opts = {
      width: "100%",
      height: "100%",
      allowscriptaccess: "always",
      wmode: "transparent",
      quality: "high",
      flashvars: "",
      movie: swf,
      name: tag
    };

    for(var index in opts) {
      if (opts.hasOwnProperty(index)) {
        element += '<param name="' + index + '" value="'+ opts[index] +'"/>';
      }
    }

    element += "</object>";

    // Insert the object into the provided tag
    document.getElementById(tag).innerHTML = element;

    // Save the reference to the Flash Player object
    this.e = document.getElementById(tempTag);
  },

  __swfReady: function() {
    this.swfready = true;

    this.__playerEvent("apiReady");
  },

  play: function(url) {
    this.e.play(url);
    return this;
  },

  stop: function() {
    this.e.stop();
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

  seek: function(timestamp) {
    console.log('seek, timestamp->' + timestamp);
  },

  playbackSpeed: function(speed) {
    console.log('playbackSpeed, speed->' + speed);
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
  },

  on: function(eventName, callback) {
    this.callbacks.push({ eventName: eventName, callback: callback });

    if (eventName === 'apiReady' && this.swfready) {
      callback.call();
    }
  },

  off: function(eventName, callback) {
    this.callbacks.forEach(function(element, index, array) {
      if((element.eventName === eventName) && (element.callback === callback)) {
        array.splice(index, 1);
      }
    });
  },

  __playerEvent: function(eventName) {
    this.callbacks.forEach(function(element, index, array) {
      if (element.eventName === eventName && element.callback) {
        element.callback.call();
      }
    });
  },
};
