//
//  VideoFeedViewModel.swift
//  HatchVideos
//
//  Created by Monica Kennedy on 2025-09-12.
//

import Foundation

@MainActor
@Observable
class VideoFeedViewModel {
    private(set) var videos: [Video] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    private var currentPage = 0
    private let pageSize = 10
    private var hasMoreVideos = true
    
    func loadVideos() async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let fetchedVideos = try await NetworkService.shared.fetchManifest()
            
            await MainActor.run {
                videos = fetchedVideos
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("Failed to load videos: \(error)")
                
                if videos.isEmpty {
                    videos = createFallbackVideos()
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    func loadMoreVideosIfNeeded() async {
        guard !isLoading && hasMoreVideos else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            let moreVideos = try await NetworkService.shared.fetchManifest()
            let newVideos = moreVideos.filter { newVideo in
                !videos.contains(where: { $0.id == newVideo.id })
            }
            
            await MainActor.run {
                videos.append(contentsOf: newVideos)
                hasMoreVideos = !newVideos.isEmpty
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("Failed to load more videos: \(error)")
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func createFallbackVideos() -> [Video] {
        let fallbackURLs = [
            "https://cdn.dev.airxp.app/AgentVideos-HLS-Progressive/000298e8-08bc-4d79-adfc-459d7b18edad/master.m3u8",
            "https://cdn.dev.airxp.app/AgentVideos-HLS-Progressive/0042b074-1533-47f8-b370-5713d536f09b/master.m3u8"
        ]
        
        return fallbackURLs.enumerated().map { index, urlString in
            guard let url = URL(string: urlString) else {
                return Video(id: "fallback-\(index)", url: URL(string: "https://example.com/video.m3u8")!)
            }
            
            let pathComponents = url.pathComponents
            let id = pathComponents[pathComponents.count - 2]
            return Video(id: id, url: url)
        }
    }
}
