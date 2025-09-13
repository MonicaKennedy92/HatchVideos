//
//  Video.swift
//  HatchVideos
//
//  Created by Monica Kennedy on 2025-09-12.
//

import Foundation

struct Video: Identifiable, Decodable, Sendable, Equatable  {
    let id: String
    let url: URL
    
    init(id: String, url: URL) {
        self.id = id
        self.url = url
    }
    
    enum CodingKeys: String, CodingKey {
        case id, url
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let urlString = try container.decode(String.self, forKey: .url)
        
        let url = URL(string: urlString)!
        let pathComponents = url.pathComponents
        let id = pathComponents[pathComponents.count - 2]
        
        self.id = id
        self.url = url
    }
}



