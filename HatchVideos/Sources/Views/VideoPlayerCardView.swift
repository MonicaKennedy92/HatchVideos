//
//  VideoPlayerCardView.swift
//  HatchVideos
//
//  Created by Monica Kennedy on 2025-09-12.
//

import SwiftUI
import AVKit
import Combine

struct VideoPlayerCard: View {
    let video: Video
    let frameHeight: CGFloat
    @EnvironmentObject private var playerManager: VideoPlayerManager
    @State private var player: AVPlayer?
    @State private var showError = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let player = player, playerManager.playbackState(for: video.id) != .failed {
                VideoPlayerView(player: player)
                    .frame(height: frameHeight)
                    .overlay(Color.black.opacity(0.2))
            } else if playerManager.playbackState(for: video.id) == .failed {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    Text("Video unavailable")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("This video couldn't be loaded")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button("Retry") {
                        Task { await setupPlayer() }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
          
        }
        .background(Color.black)
        .task {
            await setupPlayer()
        }
        .onDisappear {
            playerManager.cleanupPlayer(for: video.id)
            cancellables.removeAll()
        }
        .onChange(of: playerManager.playbackState(for: video.id)) { oldState, newState in
            if newState == .failed {
                showError = true
            }
        }
    }
    
    private func setupPlayer() async {
        if let preloadedPlayer = playerManager.getPreloadedPlayer(for: video) {
            await MainActor.run {
                player = preloadedPlayer
                setupPlaybackObservation()
            }
            return
        }
        
        await MainActor.run {
            player = playerManager.playerForVideo(video)
            setupPlaybackObservation()
        }
    }
    
    private func setupPlaybackObservation() {
        guard let player = player else { return }
        
        player.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                if status == .readyToPlay {
                    player.play()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                player.seek(to: .zero)
                player.play()
            }
            .store(in: &cancellables)
    }
}


