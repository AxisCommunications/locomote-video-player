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

  on: function(eventName, callback) {
    if (!window.Locomote.callbacks[this.id]) {
      window.Locomote.callbacks[this.id] = {};
    }

    window.Locomote.callbacks[this.id][eventName] = callback;
  },

  off: function(eventName, callback) {
    if (window.Locomote.callbacks[this.id]) {
      if (window.Locomote.callbacks[this.id][eventName]) {
        delete window.Locomote.callbacks[this.id][eventName];
      }
    }
  },

  streamStarted: function() {
    if (window.Locomote.callbacks[this.id]['streamStarted']) {
      var callback = window.Locomote.callbacks[this.id]['streamStarted'];
      callback.call();
    }
  },

  streamStopped: function() {
    if (window.Locomote.callbacks[this.id]['streamStopped']) {
      var callback = window.Locomote.callbacks[this.id]['streamStopped'];
      callback.call();
    }
  },

  streamPaused: function() {
    if (window.Locomote.callbacks[this.id]['streamPaused']) {
      var callback = window.Locomote.callbacks[this.id]['streamPaused'];
      callback.call();
    }
  },

  streamResumed: function() {
    if (window.Locomote.callbacks[this.id]['streamResumed']) {
      var callback = window.Locomote.callbacks[this.id]['streamResumed'];
      callback.call();
    }
  },

  streamError: function(errorCode, error) {
    console.log(this.e + '->streamError, errorCode: ' + errorCode + ', error: ' + error);
  }
};
