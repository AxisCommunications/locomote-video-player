/* Locomote JS Library */

/* Constructor */
function locomote(id) {
	// About object is returned if there is no 'id' parameter
	var about = {
		Version: 0.1,
		Author: "Axis Communications"
	};

	if (!window.locomote.callbacks)
		window.locomote.callbacks = {};

	if (id) {
		// return a new locomote object if we're in the wrong scope
		if (window === this) {
			return new locomote(id);
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

/* API Methods */
locomote.prototype = {
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
		if (!window.locomote.callbacks[this.id])
		{
			window.locomote.callbacks[this.id] = {};
		}

		window.locomote.callbacks[this.id][eventName] = callback;
	},

	off: function(eventName, callback) {
		if (window.locomote.callbacks[this.id])
		{
			if (window.locomote.callbacks[this.id][eventName])
			{
				delete window.locomote.callbacks[this.id][eventName];
			}
		}
	},

	streamStarted: function() {
		if (window.locomote.callbacks[this.id]['streamStarted'])
		{
			var callback = window.locomote.callbacks[this.id]['streamStarted'];
			callback.call();
		}
	},

	streamStopped: function() {
		if (window.locomote.callbacks[this.id]['streamStopped'])
		{
			var callback = window.locomote.callbacks[this.id]['streamStopped'];
			callback.call();
		}
	},

	streamPaused: function() {
		if (window.locomote.callbacks[this.id]['streamPaused'])
		{
			var callback = window.locomote.callbacks[this.id]['streamPaused'];
			callback.call();
		}
	},

	streamResumed: function() {
		if (window.locomote.callbacks[this.id]['streamResumed'])
		{
			var callback = window.locomote.callbacks[this.id]['streamResumed'];
			callback.call();
		}
	},

	streamError: function(errorCode, error) {
		console.log(this.e + '->streamError, errorCode: ' + errorCode + ', error: ' + error);
	}
};