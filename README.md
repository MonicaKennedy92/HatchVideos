1) Overview
This iOS application implements a video feed with infinite scrolling, automatic playback, and seamless looping. The app fetches HLS video streams from a provided manifest and displays them in a vertically scrollable feed.

2) Architecture

* Key Components
1. VideoPlayerManager (Singleton)
 
- Centralized management of AVPlayer instances

- Preloading and memory management

- Playback state tracking

- Error handling and recovery

2. VideoFeedViewModel

- Data fetching and management

- Pagination logic

- State management (loading, error, etc.)

3. VideoFeedView

- Main view with scrollable video feed

- Visibility tracking for playback control

4. VideoPlayerCard

- Individual video player component

- Error state handling

5. NetworkService

- Handles API communication

- Manifest fetching and parsing

* Design Patterns
- Singleton pattern for player management

- Observable pattern for state changes (using SwiftUI's @Published)

- Async/await for network operations

- MainActor for thread safety

* Memory Management Strategy

1. Active Player Management

- Only keeps a limited number of players in memory (5 by default)

- Removes distant players while preserving playback position

2. Preloading System

- Preloads adjacent videos for smooth transitions

- Uses a concurrent queue for thread-safe preloading operations

3. Cleanup Mechanism

- Proper cleanup of players when they disappear from view

- Memory warning handling to purge all players

4. State Preservation

- Saves playback positions before removing players

- Recovers players from error states

* Smooth Transition Strategy
  
1. Preloading

- Preloads next and previous videos

- Uses preloaded players when available

2. Readiness Check

- Tracks playback state to ensure videos are ready before display

- Prevents black screens by not showing videos until they're ready

3. Scroll Optimization

- Uses LazyVStack for efficient rendering

- Implements scrollTargetBehavior with paging

- Hides scroll indicators for immersive experience

* Key Design Decisions

1. Centralized Player Management

- Pros: Consistent state management, efficient resource usage

- Cons: Singleton pattern can make testing more challenging

2. MainActor Usage

- Ensures thread safety for UI updates

- Simplifies concurrency management

3. Hybrid SwiftUI/AVKit Approach

- Uses SwiftUI for UI layout

- Uses UIKit (AVKit) for video playback performance

4. Error Recovery System

- Attempts to recover from playback errors

- Provides fallback content when network fails


Build Instructions
Prerequisites
Xcode 15.0 or later

iOS 17.0 or later

Swift 5.9 or later

Steps to Build
Clone or Download the Project

bash
# If using git
git clone https://github.com/MonicaKennedy92/HatchVideos.git
cd VideoFeedApp
Open in Xcode

bash
open VideoFeedApp.xcodeproj
Or open Xcode and select "Open Existing Project"

Configure Signing

Select the project in the navigator

Select the target "VideoFeedApp"

Go to "Signing & Capabilities" tab

Select your team or use personal team for development

Build and Run

Select a target device (iPhone simulator or physical device)

Press ⌘ + R to build and run the application

Testing on Physical Device
Connect your iOS device to your Mac

Select your device from the run destination menu

Ensure your device is trusted in Xcode

Build and run (⌘ + R)


* Dependencies

1. iOS native frameworks only:

- AVKit

- SwiftUI

- Combine

- Foundation

* Configuration
- No external configuration files or environment variables needed. The manifest URL is hardcoded in NetworkService.swift.

