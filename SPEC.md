# GPX Viewer for iOS — Product Spec

Updated: 2026-01-23

## Product Overview
- Purpose: iOS app for browsing, filtering, and inspecting personal GPX tracks on a map that is independent from online services.
- Form factor: native iPhone app with a local GPX library stored on-device.
- Success: fast launch (<1s cold on modern devices), instant track list refresh after import, smooth map interaction, reliable offline use.
- Audience note: this spec is intended for contributors and maintainers.

## Target Users and Use Cases
- Outdoor enthusiasts who maintain a personal GPX library and want a private, offline-capable viewer.

## User Experience
- Layout: tabbed layout on iPhone with Map, Library, and Settings tabs.
- Library browsing: files are shown in the app's Documents directory.
- Interaction:
  - Theme: explicit Light/Dark toggle in Settings; selection persists and overrides system preference.
  - Tap a track to load (exclusive select); map auto-zooms to its bounds and switches to the Map tab; tapping the same track again deselects it; track length is shown in the Library list.
  - If a track name starts with a YYYY-MM-DD prefix, the prefix is shown as the subtitle and removed from the title in the Library list.
  - Base map selector in Settings uses the configured tile providers list; defaults to Maa-amet kaart. Selection persists per-device.
  - Current location: "locate me" button toggles follow-user; panning or zooming stops following but keeps the location indicator visible with a heading indicator.
  - Map measurement: ruler button toggles measurement mode; taps add points and show total distance; undo removes the last segment; measurements are separate from tracks.
  - Map view stays in 2D; perspective/pitch is disabled.

 
## Functional Requirements
- Library & import
  - Storage root is the app's Documents directory.
  - Import via the system Files picker (multi-select); files are copied into Documents and name collisions get a numeric suffix.
  - Documents directory changes (including iCloud/Files provider updates) trigger a rescan via NSFilePresenter on a background queue.
  - Only `.gpx` files are indexed (case-insensitive); invalid GPX surfaces an inline error state.
  - Manual "Rescan Library" action reindexes the file list.
  - Edit mode supports deleting tracks, which removes the file from Documents.
- Map tiles
  - Use native map rendering with custom tile overlays.
  - Tile providers are configurable in Settings; defaults include OpenTopoMap and Maa-amet kaart/foto (two separate layers).
  - OpenTopoMap: `https://a.tile.opentopomap.org/{z}/{x}/{y}.png`, zoom 0–15, standard XYZ.
  - Maa-amet kaart: `https://tiles.maaamet.ee/tm/tms/1.0.0/kaart@GMC/{z}/{x}/{y}.png&ASUTUS=MAAAMET&KESKKOND=LIVE&IS=TMSNAIDE`, zoom 0–19, TMS Y-axis (invert Y when building tile URLs)
  - Maa-amet foto: `https://tiles.maaamet.ee/tm/tms/1.0.0/foto@GMC/{z}/{x}/{y}.jpg&ASUTUS=MAAAMET&KESKKOND=LIVE&IS=TMSNAIDE`, zoom 0–19, TMS Y-axis; cache as JPEG to preserve content type.
  - Tile caching uses a custom on-disk cache in the app's Caches directory; cache is per-provider and can be cleared in Settings.
  - Cache keys include provider, z/x/y, and file extension; do not cache 4xx/5xx responses.
  - Cache size cap (default 1 GB) with LRU eviction; trimming runs in the background and never blocks map interaction. Users can clear the cache in Settings; size is not user-configurable.
  - Offline mode uses cache-only reads; misses surface as empty tiles without retrying.
- Map tools
  - Measurement mode draws a dashed line between tapped points and shows the cumulative distance.
  - Undo action removes the most recent measurement segment.
  - Clear action removes measurement points without affecting tracks or track markers.
- Track visualization & stats
  - GPX parsing uses a local parser; map polyline fits to bounds on load.
  - Optional distance markers render along the track when enabled; interval selectable (1/3/5/10 km).
  - Track length (km) is shown in the Library list.
  - Current location tracking uses standard iOS location permissions; foreground-only, with a user-visible indicator when active.
- Filtering & list rendering
  - Files sorted by date (filename prefix) descending with fallback to file modification date; list items grouped by year.
  - Search filters by filename or relative path (case-insensitive).
- Settings
  - Theme (Light/Dark), Offline Mode, Default Base Map, Tile Providers management, Distance Markers toggle with 1/3/5/10 km interval selector.
  - Tile Providers can be added/edited/removed with name, URL template, max zoom, TMS toggle, and file type (png/jpg).
  - Rescan Library, Reset App State.
  - Tile Cache size readout and Clear Tile Cache.
  - Diagnostics screen available by long-pressing the Version label.
  - Settings are shown in settings.png (may drift).
  - Reset App State clears stored settings back to defaults; it does not delete library files or the tile cache.
- Error handling & observability
  - GPX parse errors are shown inline; tiles that fail to load surface a non-blocking banner.
  - Basic counters for cache hits/misses/errors shown in a hidden Diagnostics screen.

## Non-Functional Requirements
- Independence from online services: core browsing and track inspection work without network access; only outbound calls are optional tile requests to configured providers (or none when Offline Mode is set).
- Performance: map remains responsive with large libraries; list filtering must feel instant.
- Footprint: Swift/SwiftUI app; minimal third-party dependencies.
- Compatibility: iOS 16+; supports iPhone only.
- Testing: unit tests cover GPX parsing, track stats, base map URLs, and tile cache; UI tests cover tab navigation and settings/base map selection.

## Constraints and Open Questions
- Tile provider rate limits and legal terms must be observed; no throttling built in.
  - Cache eviction is LRU-based with a 1 GB size cap; manual clearing remains available in Settings.

## Suggested Features (Backlog)
- Track details sheet: elevation profile with min/max/total gain/loss, duration, moving time, avg/max speed; scrubbing highlights the point on the map.
- Waypoints: render GPX waypoints as tappable pins with name/description; toggle in Settings.
- Multi-track overlay: allow multi-select in Library to compare tracks on the map with distinct colors and a small legend.
- Organization: favorites and tags; filters for favorites/tags; bulk rename/delete actions.
- Share/export: share selected tracks as GPX/GeoJSON, optionally ZIP multiple files.
- Offline trip packs: download tiles for a selected bounding box and zoom range; stored in the existing cache.
- Privacy redaction on export: optional radius mask that removes points near a chosen center before sharing.

## Security & Reliability (Summary)
- All file access is restricted to the app sandbox.
- Validate file extensions on import.
