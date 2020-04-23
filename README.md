# AVPlayer HLS streams desynchronize audio & video

Here's a screen recording of the bug: https://www.dropbox.com/s/0tr3kvl18lvrmww/AVPlayer-rate-sync-bug.mov?dl=0

## Bug

AVPlayer is streaming an HLS playlist that has multiple quality variants at a non 1.0 playback rate (1.25 in this example). This is what happens:

  * Rendition changes
  * Audio drops out for a few seconds
  * Audio comes back but is out of sync with the video. (Video is ahead of the audio)

This demo app reproduces the issue.

## Installation:

Clone

```
git clone git@github.com:dylanjha/avplayer-rate-demo.git
```

## Open in XCode

```
open *.xcodeproj
```

## See the bug

1. Build the sample app onto a test device
2. Tap the upper-right "Set: speak video" button or "Set: apple video" button - these are two different HLS sources
3. Tap "Play 1.5x" button to play at 1.5 playback rate
4. Either wait for a rendition change or force a rendition change using a tool like [Network Link Conditioner](https://nshipster.com/network-link-conditioner/)
5. When the rendition change happens audio will drop temporarily (a few seconds). When audio comes back the audio and video is out of sync

Here's a screen recording that shows the bug. When the stream switches renditions from Gear 1 to Gear 3 the audio drops momentarily and then it's out of sync https://www.dropbox.com/s/0tr3kvl18lvrmww/AVPlayer-rate-sync-bug.mov?dl=0

## Notes

* If the playback rate is 1.0, the bug does not happen
* If there is no rendition change, the bug does not happen
* This seems to happen for any non-1.0 playback rate (0.75, 1.25, 1.5, etc).
* This happens on any iPhone model that we tried and on iOS 11, 12 and 13

The team at [Speak](https://www.usespeak.com/) first reported this issue to Apple in March 2019: See [Speak TSI](https://paper.dropbox.com/doc/Speak-TSI-Mar-11-2019--Ayk98HqcPkntxhO9gpzkVuNUAg-BKbR9RCUZXTWrI9PXGWdD)
