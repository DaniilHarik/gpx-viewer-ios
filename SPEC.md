# GPX Viewer for iOS — Product Spec

Updated: 2025-12-21

## Product Overview
- Purpose: privacy-first iOS app for browsing, filtering, and inspecting personal GPX tracks on a map with offline-friendly caching.
- Form factor: native iPhone app with a local GPX library stored on-device.
- Success: fast launch (<1s cold on modern devices), instant track list refresh after import, smooth map interaction, reliable offline use.
- Audience note: this spec is intended for contributors and maintainers; end users should refer to the in-app Help screen.

## Target Users and Use Cases
- Outdoor enthusiasts who maintain a personal GPX library and want a private, offline-capable viewer.

## User Experience
- Layout: tabbed layout on iPhone with a Map + Library toggle.
- Library browsing: files are shown in the app’s Documents directory.
- Interaction:
  - Theme: explicit Light/Dark toggle in Settings; selection persists and overrides system preference.
  - Tap a track to load (exclusive select); map auto-zooms to its bounds; info panel fills with stats.
  - Base map selector: OpenTopoMap and Maa-amet kaart/foto; defaults to Maa-amet kaart. Selection persists per-device.
  - Current location: “locate me” button centers the map on the user and can follow heading until manually panned.

 
## Functional Requirements
- Library & import
  - Storage root is the app’s Documents directory .
  - Import via the system Files picker
  - iCloud Drive sync is supported for the app’s Documents directory; changes from iCloud must trigger a background-safe reindex.
  - Only `.gpx` files are indexed (case-insensitive); invalid GPX surfaces an inline error state.
  - Manual “Rescan Library” action reindexes the file list.
- Map tiles
  - Use native map rendering with custom tile overlays.
  - Tile providers: OpenTopoMap and Maa-amet kaart/foto (two separate layers).
  - OpenTopoMap: `https://a.tile.opentopomap.org/{z}/{x}/{y}.png`, zoom 0–15, standard XYZ; display attribution text in the map UI.
  - Maa-amet kaart: `https://tiles.maaamet.ee/tm/tms/1.0.0/kaart@GMC/{z}/{x}/{y}.png&ASUTUS=MAAAMET&KESKKOND=LIVE&IS=TMSNAIDE`, zoom 0–19, TMS Y-axis (invert Y when building tile URLs)
  - Maa-amet foto: `https://tiles.maaamet.ee/tm/tms/1.0.0/foto@GMC/{z}/{x}/{y}.jpg&ASUTUS=MAAAMET&KESKKOND=LIVE&IS=TMSNAIDE`, zoom 0–19, TMS Y-axis; cache as JPEG to preserve content type.
  - Tile caching uses on-disk URLCache or a custom cache directory; cache is per-provider and can be cleared in Settings.
  - Cache keys include provider, z/x/y, and file extension; do not cache 4xx/5xx responses.
  - Cache size cap (default 1 GB) with LRU eviction; trimming runs in the background and never blocks map interaction. Users can clear the cache in Settings; size is not user-configurable.
  - Offline mode uses cache-only reads; misses surface as empty tiles without retrying.
  - Offline mode: when enabled, only cached tiles are displayed (no network requests).
- Track visualization & stats
  - GPX parsing uses a local parser; map polyline fits to bounds on load.
  - Stats shown: distance (km), duration (prefers moving time), date (start timestamp localized), moving speed (km/h), elevation gain/loss (smoothed to ignore micro-noise).
  - Info panel hidden until a track is loaded; updates per selection.
  - Current location tracking uses standard iOS location permissions; foreground-only, with a user-visible indicator when active.
- Filtering & list rendering
  - Files sorted by date (filename prefix) descending; list items visually grouped by year with separators.
  - Search filters by filename or relative path (case-insensitive).
- Settings
  - Theme (Light/Dark), Offline Mode, Default Base Map, and Clear Tile Cache.
  - Settings are shown in settings.png
- Error handling & observability
  - GPX parse errors are shown inline; tiles that fail to load surface a non-blocking banner.
  - Basic counters for cache hits/misses/errors shown in a hidden Diagnostics screen.

## Non-Functional Requirements
- Privacy/offline: no third-party upload of GPX; only outbound calls are tile requests to configured providers (or none when Offline Mode is set).
- Performance: map remains responsive with large libraries; list filtering must feel instant.
- Footprint: Swift/SwiftUI app; minimal third-party dependencies.
- Compatibility: iOS 26+; supports iPhone.
- Testing: unit tests for GPX parsing, filtering, stats formatting, and export; UI tests for library import and view toggles.

## Constraints and Open Questions
- Tile provider rate limits and legal terms must be observed; no throttling built in.
  - Cache eviction is LRU-based with a 1 GB size cap; manual clearing remains available in Settings.
  - Should the app optionally watch the Documents folder for changes and auto-rescan?
- iCloud sync conflict resolution: last-writer wins.

## Security & Reliability (Summary)
- All file access is restricted to the app sandbox.
- Validate file paths and extensions on import; guard against large files that could exhaust memory.


