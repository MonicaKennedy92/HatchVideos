//
//  VideoPlayerManager.swift
//  HatchVideos
//
//  Created by Monica Kennedy on 2025-09-12.
//

import AVKit
import SwiftUI
import Combine

@MainActor
final class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()
    
    private var activePlayers: [String: AVPlayer] = [:]
    private var preloadedPlayers: [String: AVPlayer] = [:]
    private let preloadQueue = DispatchQueue(label: "com.videofeed.preload", attributes: .concurrent)
    
    @Published var currentlyPlayingId: String? = nil
    @Published var playbackStates: [String: PlaybackState] = [:]
    @Published var playbackErrors: [String: Error] = [:]
    
    private var videoUrls: [String: URL] = [:]
    private var playbackPositions: [String: CMTime] = [:]
           
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.pauseAllPlayers()
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    if let currentId = self?.currentlyPlayingId {
                        self?.playerForVideoId(currentId)?.play()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    nonisolated private func handleMemoryWarning() {
        Task { @MainActor in
            self.handleMemoryWarningOnMainActor()
        }
    }
    
    @MainActor
    private func handleMemoryWarningOnMainActor() {
        preloadQueue.async(flags: .barrier) { [weak self] in
            self?.preloadedPlayers.removeAll()
            self?.activePlayers.forEach { $0.value.pause() }
            self?.activePlayers.removeAll()
            
            DispatchQueue.main.async {
                Task { @MainActor in
                    self?.currentlyPlayingId = nil
                    self?.playbackStates.removeAll()
                    self?.playbackErrors.removeAll()
                    self?.videoUrls.removeAll()
                }
            }
        }
    }
    
    @MainActor
    func playerForVideo(_ video: Video) -> AVPlayer {
        videoUrls[video.id] = video.url
        
        if let existingPlayer = activePlayers[video.id] {
            if let position = playbackPositions[video.id] {
                existingPlayer.seek(to: position, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            return existingPlayer
        }
        
        let player = AVPlayer(url: video.url)
        activePlayers[video.id] = player
        playbackStates[video.id] = .loading
        
        if let position = playbackPositions[video.id] {
            player.seek(to: position, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        setupPlayerObservers(player: player, videoId: video.id)
        
        return player
    }

    
    @MainActor
        private func setupPlayerObservers(player: AVPlayer, videoId: String) {
            player.publisher(for: \.status)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    Task { @MainActor in
                        switch status {
                        case .readyToPlay:
                            self?.playbackStates[videoId] = .ready
                            self?.playbackErrors.removeValue(forKey: videoId)
                        case .failed:
                            self?.playbackStates[videoId] = .failed
                            if let error = player.error {
                                self?.playbackErrors[videoId] = error
                                print("Player error for video \(videoId): \(error.localizedDescription)")
                            }
                        default:
                            break
                        }
                    }
                }
                .store(in: &cancellables)
            
            player.publisher(for: \.currentItem?.status)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    Task { @MainActor in
                        guard let status = status else { return }
                        
                        switch status {
                        case .failed:
                            self?.playbackStates[videoId] = .failed
                            if let error = player.currentItem?.error {
                                self?.playbackErrors[videoId] = error
                                print("Player item error for video \(videoId): \(error.localizedDescription)")
                                
                                if let videoUrl = self?.videoUrls[videoId] {
                                    self?.recoverFromError(videoId: videoId, videoUrl: videoUrl)
                                }
                            }
                        case .readyToPlay:
                            self?.playbackStates[videoId] = .ready
                            self?.playbackErrors.removeValue(forKey: videoId)
                        default:
                            break
                        }
                    }
                }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: player.currentItem)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    Task { @MainActor in
                        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                            self?.playbackStates[videoId] = .failed
                            self?.playbackErrors[videoId] = error
                            print("Playback error for video \(videoId): \(error.localizedDescription)")
                        }
                    }
                }
                .store(in: &cancellables)
            
            let timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
                Task { @MainActor in
                    self?.playbackPositions[videoId] = time
                }
            }
            
            cancellables.insert(AnyCancellable {
                player.removeTimeObserver(timeObserver)
            })
        }
        
    nonisolated func cleanupPlayer(for videoId: String) {
          preloadQueue.async(flags: .barrier) { [weak self] in
              if let player = self?.preloadedPlayers.removeValue(forKey: videoId) {
                  player.pause()
                  player.replaceCurrentItem(with: nil)
              }
              
              if let player = self?.activePlayers[videoId] {
                  let currentTime = player.currentTime()
                  DispatchQueue.main.async {
                      Task { @MainActor in
                          self?.playbackPositions[videoId] = currentTime
                      }
                  }
                  player.pause()
              }
              
              DispatchQueue.main.async {
                  Task { @MainActor in
                      if self?.currentlyPlayingId == videoId {
                          self?.currentlyPlayingId = nil
                      }
                      
                      self?.playbackStates.removeValue(forKey: videoId)
                      self?.playbackErrors.removeValue(forKey: videoId)
                  }
              }
          }
      }
    
    
    @MainActor
       func removeDistantPlayers(except currentVideoId: String) {
           let maxPlayersToKeep = 5
           
           if activePlayers.count > maxPlayersToKeep {
               let playersToRemove = activePlayers.keys
                   .filter { $0 != currentVideoId }
                   .prefix(activePlayers.count - maxPlayersToKeep)
               
               for videoId in playersToRemove {
                   if let player = activePlayers.removeValue(forKey: videoId) {
                       playbackPositions[videoId] = player.currentTime()
                       player.pause()
                       player.replaceCurrentItem(with: nil)
                   }
               }
           }
       }
    
    @MainActor
    func pausePlayer(for videoId: String) {
        if let player = activePlayers[videoId] {
            playbackPositions[videoId] = player.currentTime()
            player.pause()
        }
    }

    @MainActor
    func playPlayer(for videoId: String) {
        currentlyPlayingId = videoId
        
        if let player = activePlayers[videoId] {
            if let position = playbackPositions[videoId] {
                player.seek(to: position, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            
            if playbackStates[videoId] != .failed {
                player.play()
            }
        } else {
            if let videoUrl = videoUrls[videoId] {
                let newPlayer = AVPlayer(url: videoUrl)
                activePlayers[videoId] = newPlayer
                playbackStates[videoId] = .loading
                
                if let position = playbackPositions[videoId] {
                    newPlayer.seek(to: position, toleranceBefore: .zero, toleranceAfter: .zero)
                }
                
                setupPlayerObservers(player: newPlayer, videoId: videoId)
                newPlayer.play()
            }
        }
    }
    @MainActor
    private func recoverFromError(videoId: String, videoUrl: URL) {
        cleanupPlayer(for: videoId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task { @MainActor in
                let newPlayer = AVPlayer(url: videoUrl)
                self.activePlayers[videoId] = newPlayer
                self.playbackStates[videoId] = .loading
                self.setupPlayerObservers(player: newPlayer, videoId: videoId)
            }
        }
    }
    
    @MainActor
    func playerForVideoId(_ videoId: String) -> AVPlayer? {
        return activePlayers[videoId]
    }
    
    nonisolated func preloadVideo(_ video: Video) {
        preloadQueue.async(flags: .barrier) { [weak self] in
            guard self?.preloadedPlayers[video.id] == nil else { return }
            
            let player = AVPlayer(url: video.url)
            self?.preloadedPlayers[video.id] = player
            
            DispatchQueue.main.async {
                Task { @MainActor in
                    self?.videoUrls[video.id] = video.url
                }
            }
        }
    }
    
    nonisolated func getPreloadedPlayer(for video: Video) -> AVPlayer? {
        var player: AVPlayer?
        preloadQueue.sync {
            player = preloadedPlayers.removeValue(forKey: video.id)
        }
        return player
    }
    
    
    nonisolated func pauseAllPlayers(except videoId: String? = nil) {
        preloadQueue.async(flags: .barrier) { [weak self] in
            self?.activePlayers.forEach { id, player in
                if id != videoId {
                    player.pause()
                }
            }
            
            self?.preloadedPlayers.forEach { $0.value.pause() }
            
            DispatchQueue.main.async {
                Task { @MainActor in
                    if let videoId = videoId {
                        self?.currentlyPlayingId = videoId
                        if self?.playbackStates[videoId] != .failed {
                            self?.playerForVideoId(videoId)?.play()
                        }
                    } else {
                        self?.currentlyPlayingId = nil
                    }
                }
            }
        }
    }
    
    @MainActor
    func setCurrentlyPlaying(_ videoId: String?) {
        currentlyPlayingId = videoId
    }
    
    @MainActor
    func playbackState(for videoId: String) -> PlaybackState {
        return playbackStates[videoId] ?? .loading
    }
    
    @MainActor
    func playbackError(for videoId: String) -> Error? {
        return playbackErrors[videoId]
    }
}

enum PlaybackState {
    case loading, ready, failed, playing, paused
}
