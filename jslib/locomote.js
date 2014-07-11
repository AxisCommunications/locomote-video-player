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
    return this.e.playerStatus();;
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

  allowFullscreen: function(state) {
    this.e.allowFullscreen(state);
    return this;
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
