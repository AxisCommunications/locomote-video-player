function Locomote(id) {
  // About object is returned if there is no 'id' parameter
  var about = {
    Author: "Axis Communications"
  };

  if (!window.Locomote.callbacks)
    window.Locomote.callbacks = {};

  if (id) {
    // return a new Locomote object if we're in the wrong scope
    if (window === this) {
      return new Locomote(id);
    }

    // Init our element object and return the object
    this.e = document.getElementById(id);
    this.id = id;
    return this;
  } else {
    // No 'id' parameter was given, return the 'about' object
    return about;
  }
}

Locomote.prototype = {
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
    console.log('streamStatus');
  },

  playerStatus: function() {
    console.log('playerStatus');
  },

  speakerVolume: function(volume) {
    console.log('speakerVolume, volume->' + volume);
  },

  muteSpeaker: function() {
    console.log('muteSpeaker');
  },

  unmuteSpeaker: function() {
    console.log('unmuteSpeaker');
  },

  microphoneVolume: function(volume) {
    console.log('microphoneVolume, volume->' + volume);
  },

  muteMicrophone: function() {
    console.log('muteMicrophone');
  },

  unmuteMicrophone: function() {
    console.log('unmuteMicrophone');
  },

  setFullScreenAllowed: function(state) {
    console.log('setFullscreenAllowed, state->' + state);
  },

  on: function(eventName, callback) {
    if (!window.Locomote.callbacks[this.id]) {
      window.Locomote.callbacks[this.id] = [];
    }

    window.Locomote.callbacks[this.id].push({ eventName: eventName, callback: callback });
  },

  off: function(eventName, callback) {
    if (!window.Locomote.callbacks[this.id]) {
      return;
    }

    window.Locomote.callbacks[this.id].forEach(function(element, index, array) {
      if((element.eventName === eventName) && (element.callback === callback)) {
        array.splice(index, 1);
      }
    });
  },

  __playerEvent: function(eventName) {
    if (!window.Locomote.callbacks[this.id]) {
      return;
    }
    
    window.Locomote.callbacks[this.id].forEach(function(element, index, array) {
      if (element.eventName === eventName) {
        element.callback.call();
      }
    });
  },
};
