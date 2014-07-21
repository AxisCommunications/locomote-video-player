function Locomote(id) {
  this.callbacks = [];
  this.apiReady = false;

  if (id) {
    // return a new Locomote object if we're in the wrong scope
    if (window === this) {
      window.Locomote[id] = new Locomote(id);
      return window.Locomote[id];
    }
    if (!window.Locomote[id]) {
      window.Locomote[id] = this;
    } else {
      return window.Locomote[id];
    }
    // Init our element object and return the object
    this.e = document.getElementById(id);
    this.id = id;
    return this;
  } else {
    // No 'id' parameter was given, return null
    return null;
  }
}

Locomote.prototype = {
  isReady: function() {
    // Returns the ready status to the Flash Player
    return this.apiReady;
  },

  start: function() {
    // Set the ready status to true and start listening for events
    this.apiReady = true;
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
      if (element.eventName === eventName) {
        if (element.callback) {
          element.callback.call();
        }
      }
    });
  },
};
