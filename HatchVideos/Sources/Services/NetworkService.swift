//
//  NetworkService.swift
//  HatchVideos
//
//  Created by Monica Kennedy on 2025-09-12.
//

import Foundation

actor NetworkService {
    static let shared = NetworkService()
    private let session: URLSession
    private let manifestURL = URL(string: "https://cdn.dev.airxp.app/AgentVideos-HLS-Progressive/manifest.json")!
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    func fetchManifest() async throws -> [Video] {
        let (data, response) = try await session.data(from: manifestURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let manifest = try JSONDecoder().decode(VideoManifest.self, from: data)
        return manifest.toVideos()
    }
}
