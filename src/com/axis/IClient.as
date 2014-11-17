package com.axis {
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
     * Called when the client should start the stream.
     * Any connections should be made at this point
     */
    function start():Boolean;

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
     * Called when the client should buffer a certain amount seconds
     * before continuing playback.
     */
    function setBuffer(seconds:Number):Boolean;

    /**
     * If the stream the client currently is playing has video.
     */
    function hasVideo():Boolean;

    /**
     * If the stream the client currently is playing has audio.
     */
    function hasAudio():Boolean;

    /**
     * Returns the current achieved frames per second for the client.
     */
    function currentFPS():Number;
  }
}
