package com.axis {
  import flash.display.DisplayObject;
  import flash.events.IEventDispatcher;

  /**
   * The interface to implement for a client to be used by Player.
   * In addidtion the the methods enforced in this interface, it should
   * emit ClientEvent for certain actions:
   *
   *  - ClientEvent.NETSTREAM_CREATED for automatic video resizing and other goodies.
   */
  public interface IClient extends IEventDispatcher {

    /**
     * Should return the area where the video the client
     * produces should be shown. This must be an instance of DisplayObject.
     */
    function getDisplayObject():DisplayObject;

    /**
     * Should return the position of the playahead, in milliseconds.
     * Returns -1 if unavailable
     */
    function getCurrentTime():Number;

    /**
     * Should return the size of the playback buffer in milliseconds.
     * Returns -1 if unavailable
     */
    function bufferedTime():Number;

    /**
     * Called when the client should start the stream.
     * Any connections should be made at this point
     * options include optional offset, the time in the stream to start playing
     * at.
     */
    function start(options:Object):Boolean;

    /**
     * Called when the client should stop the stream.
     * The video/audio should stop playing at this pont
     * and all connections should be terminated.
     */
    function stop():Boolean;

    /**
     * Called when the client should seek in the stream
     * to a given position (in sec).
     */
    function seek(position:Number):Boolean;

    /**
     * Called when the client should pause the stream. This should
     * preferrably be accomplished by pausing the incomming stream,
     * but this may not always be possible. If that is not possible,
     * the client should return false and pausing will be accomplished
     * in the player.
     */
    function pause():Boolean;

    /**
     * Called when the stream should be resumed. This will only be
     * called if the client previously claimed to have paused the
     * stream by returning `true` from a call to `stop`.
     */
    function resume():Boolean;

    /**
     * Called when the client should emit an event for each frame and wait for
     * a call to playFrames to play the frames.
     * Returns false if the action is not possible.
     */
    function setFrameByFrame(frameByFrame:Boolean):Boolean;

    /**
     * Call to play all frames with timestamp equal to or lower than the given
     * timestamp.
     * A call to this function does nothing if a previous call to
     * setFrameByFrame(true) has not been made.
     */
    function playFrames(timestamp:Number):void;

    /**
     * Called when the client should buffer a certain amount seconds
     * before continuing playback.
     */
    function setBuffer(seconds:Number):Boolean;

   /**
     * Called when the client should start keep alive routine
     */
    function setKeepAlive(seconds:Number):Boolean;

    /**
     * Returns the current achieved frames per second for the client.
     */
    function currentFPS():Number;
  }
}
