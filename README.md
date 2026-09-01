# Mastering Lock Screen & Now Playing Metadata in iOS with MPNowPlayingInfoCenter

This repo is the finalized, ready-to-run version of the demo app from my article:

**[Mastering Lock Screen & Now Playing Metadata in iOS with MPNowPlayingInfoCenter](https://mzeeshan.me/blog/swiftui-background-audio-player-lock-screen-controls)**

<img width="2000" height="1000" alt="Background audio demo app final results screenshots" src="https://github.com/user-attachments/assets/a1944522-7eb8-46dc-85f2-c6a52d042269" />

## Summary of the article

When you build audio playback into an iOS app, the part that trips everyone up is what happens after the phone locks or the app goes in the background: a blank lock screen, no artwork, non interactive player UI, while apps like Spotify and Apple Music sit there looking perfect.

The article walks through closing that gap with `MPNowPlayingInfoCenter` one system-wide dictionary that the lock screen, Control Center, CarPlay, Apple Watch, and AirPods all read from. It covers:

- **The three prerequisites** that decide whether iOS shows your player at all: the Background Modes (Audio) capability, an `AVAudioSession` set to `.playback`, and registered handlers on `MPRemoteCommandCenter`. Miss any one of them and the API fails silently.
- **The snapshot model for the progress bar.** You don't push elapsed time every second. You set elapsed time + playback rate + duration once per state change (play, pause, seek), and the system animates the scrubber on its own.
- **Artwork done lazily** with `MPMediaItemArtwork` and its request handler, so nothing blocks.
- **Cleanup and gotchas**. Clearing stale info, why the simulator lies about Now Playing behavior, and how `AVPlayerViewController` will overwrite your dictionary if you don't pick an owner.

## What the app does

A minimal SwiftUI player, built entirely around the article:

- Plays a bundled `sample.mp3` in the background with play/pause and a scrub slider
- Reads the file's **full embedded metadata** using the modern async `AVAsset` loading APIs — title, artist, album, and artwork for the header, plus every raw ID3 tag listed below the player so you can see exactly what your file carries
- Publishes that metadata to `MPNowPlayingInfoCenter`, giving you a fully interactive player on the lock screen and in Control Center — artwork, title, a live scrubber you can drag, and working play/pause

## Setup

1. Open the project in Xcode and select your target.
2. **Signing & Capabilities → + Capability → Background Modes** → check **Audio, AirPlay, and Picture in Picture**. Without this, audio stops the moment the phone locks.
3. Make sure `sample.mp3` is in the bundle with the target checked.
4. Run on a **real device**. Now Playing behavior on the simulator ranges from flaky to absent — don't debug against it.

Play the audio, lock the phone, and your metadata should be sitting on the lock screen with working controls.

## About the sample file

The bundled `sample.mp3` comes from my own collection of test files:

**[Audio sample files — mzeeshan.me](https://mzeeshan.me/tools/sample-files/category/audios)**

Use a file with real embedded tags when testing metadata pipelines. The collection has MP3, M4A and FLAC variants with proper metadata embedded for exactly this kind of testing.

## Requirements

- Xcode 15+
- iOS 16+ deployment target (uses the async `AVAsset`/`AVMetadataItem` loading APIs)
- A physical device for lock screen testing
