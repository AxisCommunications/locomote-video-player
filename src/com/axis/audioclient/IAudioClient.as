package com.axis.audioclient {
  /**
   * The interface to implement for an audio client to be used by Player.
   */
  public interface IAudioClient {
    /**
     * Getter for the microphone volume.
     */
    function get microphoneVolume():Number;

    /**
     * Setter for the microphone volume.
     * The API expects the volume to be normalized to
     * values between 0-100.
     */
    function set microphoneVolume(volume:Number):void;

    /**
     * Called when the microphone should be muted.
     * The orignal volume should be saved so that it can
     * be restored when the microphone is unmuted.
     */
    function muteMicrophone():void;

    /**
     * Called when the microphone should be unmuted.
     * When unmuting the volume should be reset to the
     * original value before muting.
     */
    function unmuteMicrophone():void;
  }
}