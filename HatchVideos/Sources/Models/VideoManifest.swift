//
//  VideoManifest.swift
//  HatchVideos
//
//  Created by Monica Kennedy on 2025-09-12.
//

import Foundation

struct VideoManifest: Decodable, Sendable {
    let videos: [String]
    
    func toVideos() -> [Video] {
        return videos.compactMap { urlString in
            guard let url = URL(string: urlString) else { return nil }
            
            let pathComponents = url.pathComponents
            guard pathComponents.count >= 2 else { return nil }
            
            let id = pathComponents[pathComponents.count - 2]
            return Video(id: id, url: url)
        }
    }
}
