# Teach Me To Live (iOS)

A hyper-minimalist iOS app for sharing short-lived wisdom.  
Design: black background, white text, 3 views (Welcome, Repository, Add Wisdom).  
Data: Firebase (real-time sync). **Posts expire after ~1 month.**  
App Store: https://apps.apple.com/us/app/teach-me-to-live/id67456466371

## Features
- ~30-day ephemeral posts (auto-expire)
- One submission per day
- Minimal UI/UX

## Requirements
- Xcode 15+
- iOS 17+
- Swift Package Manager (SPM)
- Firebase (via SPM)

## Dev Setup
1. Open the project in Xcode.
2. File → Add Packages… add Firebase packages used (Firestore, Auth, etc.).
3. Add your `GoogleService-Info.plist` to the app target.
4. Build & run.

## Screens / Flow
- **Welcome** → timed text fades + rain effect
- **Repository** → scrollable list of entries (30-day lifetime)
- **Add Wisdom** → one post/day, short character limit

> This repo is mainly for viewing/learning. No license = not open for reuse.
