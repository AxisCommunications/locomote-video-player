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
      window.Locomote.callbacks[this.id] = [];
    }

    window.Locomote.callbacks[this.id].push({ eventName: eventName, callback: callback });
  },

  off: function(eventName, callback) {
    if (!window.Locomote.callbacks[this.id]) {
      return;
    }

    for (var i in window.Locomote.callbacks[this.id]) {
      if ((window.Locomote.callbacks[this.id][i].eventName === eventName) && (window.Locomote.callbacks[this.id][i].callback === callback)) {
        window.Locomote.callbacks[this.id].splice(i, 1);
      }
    }
  },

  __playerEvent: function(eventName) {
    if (!window.Locomote.callbacks[this.id]) {
      return;
    }
     
    for (var i in window.Locomote.callbacks[this.id]) {
      if (window.Locomote.callbacks[this.id][i].eventName === eventName) {
        window.Locomote.callbacks[this.id][i].callback.call();
      }
    }
  },
};
