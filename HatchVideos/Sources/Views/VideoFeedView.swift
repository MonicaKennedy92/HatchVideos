//
//  VideoFeedView.swift
//  HatchVideos
//
//  Created by Monica Kennedy on 2025-09-12.
//

import SwiftUI
import AVKit
import Combine

struct VideoFeedView: View {
    @State private var viewModel = VideoFeedViewModel()
    @State private var visibleItem: String?
    @EnvironmentObject private var playerManager: VideoPlayerManager
    @State private var showingError = false
    @State private var isLoadingMore = false
    @State private var lastVisibleItem: String?

    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.videos.isEmpty && viewModel.isLoading {
                    ProgressView("Loading videos...")
                        .scaleEffect(1.5)
                } else if viewModel.videos.isEmpty {
                    ContentUnavailableView(
                        "No Videos",
                        systemImage: "video.slash",
                        description: Text("Could not load videos. Please check your connection.")
                    )
                } else {
                    videoScrollView(for: geometry)
                }
            }
            .task { await viewModel.loadVideos() }
            

            .onChange(of: visibleItem) { oldValue, newValue in
                guard oldValue != newValue else { return }
                handleVisibleItemChange(oldValue: oldValue, newValue: newValue)
            }
            
            .onChange(of:viewModel.videos) { oldValue, newValue in
                                
                if visibleItem == nil && !newValue.isEmpty {
                    visibleItem = newValue.first?.id
                }
            }

            .alert("Error", isPresented: $showingError, presenting: viewModel.error) {_ in 
                       Button("OK") { }
                       Button("Retry") {
                           Task { await viewModel.loadVideos() }
                       }
                   } message: { error in
                       Text(error.localizedDescription)
                   }
        }
    }
    
    private func videoScrollView(for geometry: GeometryProxy) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.videos) { video in
                    VideoPlayerCard(video: video, frameHeight: geometry.size.height)
                        .id(video.id)
                        .containerRelativeFrame(.vertical)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(height: geometry.size.height)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleItem)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
    }
    


    private func handleVisibleItemChange(oldValue: String?, newValue: String?) {
            guard let newValue = newValue else { return }
            
            if let oldValue = oldValue {
                playerManager.pausePlayer(for: oldValue)
            }
            
            playerManager.playPlayer(for: newValue)
            
            if let currentIndex = viewModel.videos.firstIndex(where: { $0.id == newValue }) {
                let nextIndex = currentIndex + 1
                if nextIndex < viewModel.videos.count {
                    playerManager.preloadVideo(viewModel.videos[nextIndex])
                }
                
                let prevIndex = currentIndex - 1
                if prevIndex >= 0 {
                    playerManager.preloadVideo(viewModel.videos[prevIndex])
                }
                
                if currentIndex == viewModel.videos.count - 3 {
                    isLoadingMore = true
                    Task {
                        await viewModel.loadMoreVideosIfNeeded()
                        isLoadingMore = false
                    }
                }
                
                playerManager.removeDistantPlayers(except: newValue)
            }
            
            lastVisibleItem = newValue
        }
    
    private func handleVideosChange(oldValue: [Video], newValue: [Video]) {
        if visibleItem == nil && !newValue.isEmpty {
            visibleItem = newValue.first?.id
        }
    }
    
    private func handleErrorChange(oldValue: Error?, newValue: Error?) {
        showingError = newValue != nil
    }
    
    private var alertButtons: some View {
        Group {
            Button("OK") { }
            Button("Retry") {
                Task { await viewModel.loadVideos() }
            }
        }
    }
}









