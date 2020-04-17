# AVPlayer HLS streams desynchronize audio & video when playback rate is not 1.0 and player switches quality streams

Description:

We’re using AVPlayer to stream HLS videos with several video quality variants. When we set playback rate to 1.25, 1.5, 0.75 (or anything that is not 1.0), and AVPlayer switches to a different variant stream, the player drops audio for 1-10 seconds and desyncs audio and video (video is ahead of audio). 

When we pause playback and play again, it seems that the video is frozen in place while audio plays, until the audio track catches up to the video, upon which time the video resumes moving and both video and audio continue playing in sync.

This issue seems to be specifically associated with a change in variant stream coupled with playback at a non-1.0 rate. 

- If the rate is 1.0, this never happens.
- If the variant stream does not change, this issue never happens. 
- If the issue happens and we play/pause as described previously, and the variant stream does not change again, then the issue never happens again.


Configuration:
This happens on many different iPhone models in production and on both iOS 11 and iOS 12. It shouldn’t be hard to reproduce.

Steps to reproduce:

1. Open and build the sample project we attached to device.
2. Tap the upper-right “Set: speak video” button
3. Tap the “Play 1.25x” button to play at rate 1.25.
4. Listen to the audio and wait for the video stream to visually switch to a higher quality. You have to wait until it changes, which is dependent on your network conditions.
    1. Our provided video has 2 variant streams marked with Gear 1 and Gear 2.
5. Right as the stream switches on screen, audio should drop out temporarily, and the video and audio are now no longer synced
6. Press pause and look at the playTime label. When you press play, the playTime will jump back in time and audio will start playing, but the video will still be frozen. A short time later, the audio will catch up to the video and then they will both start playing in sync.

Note: also try pressing the “set apple video” button on the upper right to set the video again, and observe the issue again with an official Apple HLS stream.

