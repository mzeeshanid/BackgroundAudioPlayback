//
//  ContentView.swift
//  AudioPlayerTest
//
//  Created by Zeeshan on 31/08/2026.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

struct ContentView: View {
    @StateObject private var audio = AudioManager()

    // Drives only the in-app slider. Deliberately not wired to Now Playing.
    private let uiTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    playerCard
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                }

                if let error = audio.loadError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section("Embedded Metadata (\(audio.allMetadata.count) tags)") {
                    if audio.allMetadata.isEmpty {
                        Text("No tags found — try an MP3 with real embedded metadata.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(audio.allMetadata) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.value)
                                .font(.body)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Now Playing Demo")
            .onReceive(uiTimer) { _ in
                audio.refreshTime()
            }
        }
    }

    private var playerCard: some View {
        VStack(spacing: 16) {
            artworkView

            VStack(spacing: 4) {
                Text(audio.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(audio.album.map { "\(audio.artist) — \($0)" } ?? audio.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { audio.currentTime },
                        set: { audio.currentTime = $0 }
                    ),
                    in: 0...max(audio.duration, 1)
                ) { editing in
                    audio.isScrubbing = editing
                    if !editing {
                        audio.seek(to: audio.currentTime)
                    }
                }

                HStack {
                    Text(timeString(audio.currentTime))
                    Spacer()
                    Text(timeString(audio.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Button {
                audio.togglePlayPause()
            } label: {
                Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = audio.artwork {
            Image(uiImage: artwork)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 6, y: 3)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .frame(width: 200, height: 200)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    ContentView()
}
