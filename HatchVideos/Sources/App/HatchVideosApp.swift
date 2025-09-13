//
//  HatchVideosApp.swift
//  HatchVideos
//
//  Created by Monica Kennedy on 2025-09-11.
//

import SwiftUI

@main
struct HatchVideosApp: App {
    var body: some Scene {
        WindowGroup {
            VideoFeedView()
                .environmentObject(VideoPlayerManager.shared)
                .preferredColorScheme(.dark) 
        }
    }
}
