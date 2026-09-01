//
//  AudioManager.swift
//  AudioPlayerTest
//
//  Created by Zeeshan on 01/09/2026.
//

import Combine
import AVFoundation
import SwiftUI
import MediaPlayer

// MARK: - Audio manager

@MainActor
final class AudioManager: NSObject, ObservableObject {

    // Playback state (drives the in-app UI)
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isScrubbing = false

    // Headline metadata (drives the player header + Now Playing)
    @Published var title = "Unknown Title"
    @Published var artist = "Unknown Artist"
    @Published var album: String?
    @Published var artwork: UIImage?

    // Every tag found in the file (drives the List)
    @Published var allMetadata: [MetadataEntry] = []
    @Published var loadError: String?

    private var player: AVAudioPlayer?

    override init() {
        super.init()
        configureAudioSession()
        preparePlayer()
        configureRemoteCommands()
        Task { await loadMetadata() }
    }

    // MARK: Prerequisite 2 — the audio session
    // .playback is what tells iOS this audio deserves lock screen presence.
    // The default (.soloAmbient) is "decorative" audio and gets no controls.

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            loadError = "Audio session error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Player
extension AudioManager {
    private func preparePlayer() {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
            loadError = "sample.mp3 not found in the app bundle. Add it to the target."
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            self.duration = player.duration
        } catch {
            loadError = "Player error: \(error.localizedDescription)"
        }
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
        updatePlaybackSnapshot()
    }

    func pause() {
        guard let player else { return }
        player.pause()
        isPlaying = false
        updatePlaybackSnapshot()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, time), duration)
        currentTime = player.currentTime
        updatePlaybackSnapshot()
    }

    /// Called by the view on a lightweight timer, purely to move the in-app
    /// slider. Note what it does NOT do: touch MPNowPlayingInfoCenter.
    /// The system animates the lock screen scrubber on its own from the
    /// elapsed-time + rate snapshot we set on state changes.
    func refreshTime() {
        guard let player, isPlaying, !isScrubbing else { return }
        currentTime = player.currentTime
    }
}

// MARK: - Playback finished
extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.player?.currentTime = 0
            self.updatePlaybackSnapshot()
        }
    }
}

// MARK: - Now Playing
extension AudioManager {
    private func publishNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: artwork.size
            ) { _ in
                artwork
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// The snapshot update from the article: elapsed time + rate, set only when
    /// state actually changes (play, pause, seek). Never on a timer.
    private func updatePlaybackSnapshot() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - Remote Command Center
extension AudioManager {
    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()

        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }

        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }

        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }

        // A single-track demo supports no skipping — disable instead of
        // leaving dead buttons on the lock screen.
        commands.nextTrackCommand.isEnabled = false
        commands.previousTrackCommand.isEnabled = false
    }
}

// MARK: - Metadata
// Two passes over the asset:
//   1. commonMetadata — normalized keys (title, artist, album, artwork)
//      that we use for the header and Now Playing info.
//   2. every available format (ID3 for MP3) — the raw tag list shown in
//      the List, so you can see exactly what your file carries.
extension AudioManager {
    private func loadMetadata() async {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") else { return }
        let asset = AVURLAsset(url: url)

        do {
            // Pass 1 — the headline fields
            let common = try await asset.load(.commonMetadata)
            for item in common {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let value = try await item.load(.stringValue) { title = value }
                case .commonKeyArtist:
                    if let value = try await item.load(.stringValue) { artist = value }
                case .commonKeyAlbumName:
                    album = try await item.load(.stringValue)
                case .commonKeyArtwork:
                    if let data = try await item.load(.dataValue) {
                        artwork = UIImage(data: data)
                    }
                default:
                    break
                }
            }

            // Pass 2 — everything, for the List
            var entries: [MetadataEntry] = []
            let formats = try await asset.load(.availableMetadataFormats)
            for format in formats {
                let items = try await asset.loadMetadata(for: format)
                for item in items {
                    let label = Self.prettyLabel(for: item)
                    if let value = try await Self.readableValue(of: item) {
                        entries.append(MetadataEntry(label: label, value: value))
                    }
                }
            }
            allMetadata = entries

            // Metadata is in — publish the full picture to the system.
            publishNowPlayingInfo()
        } catch {
            loadError = "Metadata error: \(error.localizedDescription)"
        }
    }

    private static func prettyLabel(for item: AVMetadataItem) -> String {
        if let common = item.commonKey?.rawValue {
            // "albumName" -> "Album Name"
            let spaced = common.replacingOccurrences(
                of: "([a-z])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            return spaced.capitalized
        }
        if let identifier = item.identifier?.rawValue {
            // "id3/TALB" -> "TALB (ID3)"
            let parts = identifier.split(separator: "/")
            if parts.count == 2 {
                return "\(parts[1]) (\(parts[0].uppercased()))"
            }
            return identifier
        }
        return "Unknown Tag"
    }

    private static func readableValue(of item: AVMetadataItem) async throws -> String? {
        if let string = try await item.load(.stringValue), !string.isEmpty {
            return string
        }
        if let number = try await item.load(.numberValue) {
            return number.stringValue
        }
        if let date = try await item.load(.dateValue) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        if let data = try await item.load(.dataValue) {
            // Artwork and other binary tags — show size instead of bytes.
            return "Binary data (\(data.count.formatted()) bytes)"
        }
        return nil
    }
}
