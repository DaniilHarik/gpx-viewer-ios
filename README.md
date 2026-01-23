# GPX Viewer for iOS

Privacy-first iOS app for browsing GPX tracks on a map with offline-friendly tile caching.

## Features
- Local GPX library stored in the app Documents directory.
- Import via Files picker with multi-select and duplicate name handling.
- Map view with track overlay, distance markers, and a measurement tool.
- Base map options: configurable tile providers (defaults include OpenTopoMap and Maa-amet kaart/foto).
- Offline mode uses cache-only map tiles.
- Tile cache with size readout, clear action, and background LRU trimming.

## Requirements
- Xcode with iOS 16 SDK.
- iPhone device or simulator running iOS 16+.

## Install and Run
1. Clone the repo.
2. Open `GPXViewer.xcodeproj` in Xcode.
3. Select a simulator or device (iOS 16+).
4. Build and run.

## Usage
- Import tracks: open the Library tab and tap the import button.
- View a track: tap a file to load it and jump to the Map tab.
- Track length: shown in the Library list.
- Measure distance: tap the ruler button, then tap the map to add points and clear.
- Settings: choose theme, offline mode, base map, tile providers, and distance markers.

## Architecture
- SwiftUI app with a `MapView` bridge to `MKMapView`.
- Library indexing from Documents with `NSFilePresenter` and async scanning.
- GPX parsing via `GPXParser` into `GPXTrack` and `TrackStats`.
- Tile overlays via `CachedTileOverlay` with on-disk cache in Caches.
- Diagnostics view surfaced by long-pressing the Settings version label.

## Tile Providers
Defaults include OpenTopoMap and Maa-amet kaart/foto. You can add custom providers with a URL template,
max zoom, TMS toggle, and file type (png/jpg). Offline mode uses cached tiles only.

If you ship this app, ensure your usage complies with each provider's terms and rate limits.

## Privacy
- GPX files stay in the app sandbox and are never uploaded.
- Network access is limited to map tile requests for configured providers (or none when Offline Mode is on).

## Contributing
- Keep changes aligned with `SPEC.md`.
- Run tests before opening a PR.
- For UI changes, include screenshots where possible.

## License
Add a license file and update this section. If you're unsure, MIT or Apache-2.0 are common choices.

## Project Notes
- Bundle identifier: `ee.impero.gpxviewer`.
