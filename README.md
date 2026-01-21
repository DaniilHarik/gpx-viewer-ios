# GPX Viewer for iOS

Privacy-first iOS app for browsing GPX tracks on a map with offline-friendly tile caching.

## Features
- Local GPX library stored in the app Documents directory.
- Import via Files picker with multi-select and duplicate name handling.
- Map view with track overlay, optional 1 km distance markers, track stats, and a measurement tool.
- Base map options: configurable tile providers (defaults include OpenTopoMap and Maa-amet kaart/foto).
- Offline mode uses cache-only map tiles.
- Tile cache with size readout, clear action, and background LRU trimming.

## Requirements
- Xcode with iOS 16 SDK.
- iPhone device or simulator running iOS 16+.

## Setup
1. Open `GPXViewer.xcodeproj` in Xcode.
2. Select a simulator or device (iOS 16+).
3. Build and run.

## Usage
- Import tracks: open the Library tab and tap the import button.
- View a track: tap a file to load it and jump to the Map tab.
- Track stats: tap the info button on the map.
- Measure distance: tap the ruler button, then tap the map to add points and clear.
- Settings: choose theme, offline mode, base map, tile providers, and distance markers.

## Architecture
- SwiftUI app with a `MapView` bridge to `MKMapView`.
- Library indexing from Documents with `NSFilePresenter` and async scanning.
- GPX parsing via `GPXParser` into `GPXTrack` and `TrackStats`.
- Tile overlays via `CachedTileOverlay` with on-disk cache in Caches.
- Diagnostics view surfaced by long-pressing the Settings version label.

## Project Notes
- Bundle identifier: `ee.impero.gpxviewer`.
- When changing features, update `SPEC.md`.
