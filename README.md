# GPX Viewer for iOS

Independent-from-online-services iOS app for browsing GPX tracks on a map with offline-friendly tile caching.

## Features
- Local GPX library stored in the app Documents directory with automatic rescans.
- Import via Files picker (multi-select) or share sheet/Open in with duplicate name handling.
- Library tools: search by name/path, star favorites, rename, delete, and track length display.
- Map view with custom tile providers, 2D track overlay, distance markers (1/3/5/10 km), waypoints, and a measurement tool (undo/clear).
- Base map selection (defaults include OpenTopoMap, OpenStreetMap, and Maa-amet kaart/foto) with offline mode.
- Tile cache (1 GB LRU) with size readout, clear action, and diagnostics counters.
- Explicit Light/Dark theme toggle.

## Requirements
- Xcode with iOS 26 SDK.
- iPhone device or simulator running iOS 26+.

## Install and Run
1. Clone the repo.
2. Open `GPXViewer.xcodeproj` in Xcode.
3. Select a simulator or device (iOS 26+).
4. Build and run.

## Usage
- Import tracks: open the Library tab and tap the import button.
- View a track: tap a file to load it and jump to the Map tab.
- Track length: shown in the Library list.
- Measure distance: tap the ruler button, then tap the map to add points; undo or clear as needed.
- Star or rename: long-press a track row for quick actions.
- Settings: choose theme, offline mode, base map, tile providers, distance markers, and waypoints.
- Diagnostics: long-press the Version label in Settings.

## Architecture
- SwiftUI app with a `MapView` bridge to `MKMapView`.
- Library indexing from Documents with `NSFilePresenter` and debounced async scanning.
- GPX parsing via `GPXParser` into `GPXTrack` and `TrackStats`.
- Tile overlays via `CachedTileOverlay` with on-disk cache in Caches.
- Diagnostics view surfaced by long-pressing the Settings version label.

## Tile Providers
Defaults include OpenTopoMap, OpenStreetMap, and Maa-amet kaart/foto (default base map is Maa-amet kaart).
You can add custom providers with a URL template, max zoom, TMS toggle, and file type (png/jpg). Offline mode uses cached tiles only.

If you ship this app, ensure your usage complies with each provider's terms and rate limits.

## Independence from Online Services
- GPX files stay in the app sandbox and are never uploaded.
- Network access is limited to map tile requests for configured providers (or none when Offline Mode is on).

## Contributing
- Keep changes aligned with `SPEC.md`.
- Run tests before opening a PR.
- For UI changes, include screenshots where possible.

## License
MIT License. See `LICENSE`.

## Project Notes
- Bundle identifier: `ee.impero.gpxviewer`.
