# GPX Viewer for iOS — Product Spec

Updated: 2026-01-28

## Product Overview
- Purpose: iOS app for browsing, filtering, and inspecting personal GPX tracks on a map that is independent from online services.
- Form factor: native iPhone app with a local GPX library stored on-device.
- Success: fast launch (<1s cold on modern devices), instant track list refresh after import, smooth map interaction, reliable offline use.
- Audience note: this spec is intended for contributors and maintainers.

## Target Users and Use Cases
- Outdoor enthusiasts who maintain a personal GPX library and want a private, offline-capable viewer.

## User Experience
- Layout: tabbed layout on iPhone with Map, Tracks, Points, and Settings tabs.
- Tracks browsing: files are shown in the app's Documents directory.
- Interaction:
  - Theme: explicit Light/Dark toggle in Settings; selection persists and overrides system preference.
  - Tap a track to load (exclusive select); map auto-zooms to its bounds and switches to the Map tab; tapping the same track again deselects it; track length is shown in the Tracks list.
  - If a track name starts with a YYYY-MM-DD prefix, the prefix is shown as the subtitle and removed from the title in the Tracks list.
  - Base map selector in Settings uses the configured tile providers list; defaults to Maa-amet kaart. Selection persists per-device.
  - Base map selection rows in Settings are fully tappable across the entire row.
  - Current location: "locate me" button toggles follow-user; panning or zooming stops following but keeps the location indicator visible with a heading indicator.
  - Map measurement: ruler button toggles measurement mode; taps add points and show total distance; undo removes the last segment; measurements are separate from tracks.
  - Measurement control uses the standard navigation bar background color; active state shows an orange ruler icon.
  - Measurement summary is a compact pill attached to the measurement control near the bottom-left, with the same background color, orange accents, and drop shadow.
  - Locate-me button uses the same background; active state shows a blue location icon.
  - Map view stays in 2D; perspective/pitch is disabled.
  - Selecting a track shows a loading overlay on the Map tab (after a 250 ms delay) until the track polyline is ready; base map tiles do not need to finish loading.
  - Rapid track switching always favors the most recent selection; earlier in-flight parses are ignored.
  - Waypoints render as tappable pins that show name only when enabled; descriptions are intentionally not shown to avoid map clutter.
  - Points: saved points list shows icon, title, and coordinates; selecting a point jumps to the Map tab and centers on the point marker.

 
## Functional Requirements
- Tracks & import
  - Storage root is the app's Documents directory.
  - Import via the system Files picker (multi-select); files are copied into Documents and name collisions get a numeric suffix.
  - Accept GPX files shared from other apps (share sheet/Open in) and import them into Documents with the same duplicate name handling.
  - Files opened from Files are not opened in place; they are copied into Documents.
  - Files staged in Documents/Inbox are moved into Documents on import and are not shown as separate library entries.
  - Documents directory changes (including iCloud/Files provider updates) trigger a rescan via NSFilePresenter on a background queue.
  - Track list rescans are debounced to coalesce rapid file system updates.
  - Only `.gpx` files are indexed (case-insensitive); invalid GPX surfaces an inline error state.
  - Track list rescans run automatically when Documents changes are observed.
  - Track stats and parse error state are cached per file and recomputed only when the file modification date changes.
  - Edit mode supports deleting tracks, which removes the file from Documents.
- Map tiles
  - Use native map rendering with custom tile overlays.
- Tile providers are configurable in Settings; defaults include OpenTopoMap, OpenStreetMap, and Maa-amet kaart/foto (two separate layers).
- OpenTopoMap: `https://a.tile.opentopomap.org/{z}/{x}/{y}.png`, zoom 0–15, standard XYZ.
- OpenStreetMap: `https://c.tile.openstreetmap.org/{z}/{x}/{y}.png`, zoom 0–19, standard XYZ.
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
  - Optional waypoints render as tappable pins with name only; descriptions are intentionally not shown to avoid map clutter.
  - Track length (km) is shown in the Tracks list.
  - Current location tracking uses standard iOS location permissions; foreground-only, with a user-visible indicator when active.
- Filtering & list rendering
  - Files sorted by date (filename prefix) descending with fallback to file modification date; list items grouped by year.
  - Search filters by filename or relative path (case-insensitive).
  - Tracks list supports starring tracks; starred tracks appear in a separate top group and are removed from year sections.
  - Star state persists on-device and is cleared automatically when a starred file is deleted.
  - Tracks can be renamed from the Tracks tab; renaming updates the underlying file in Documents and preserves stars/selection.
- Points
  - Points are stored on-device and persist between launches.
  - Each point includes a title, SF Symbol icon, latitude, and longitude in decimal degrees.
  - Add point supports filling coordinates from the current location (with location permission).
  - Points can be added, edited, starred, and deleted.
  - Starred points appear in a top group above the main points list.
  - Selecting a point shows a marker on the Map tab and centers the map on it.
  - Long-pressing a point offers a Copy Coordinates action that copies "lat lon" for pasting into maps.
- Settings
  - Theme (Light/Dark), Offline Mode, Default Base Map, Tile Providers management, Distance Markers toggle with 1/3/5/10 km interval selector, Waypoints toggle.
  - Tile Providers can be added/edited/removed with name, URL template, max zoom, TMS toggle, and file type (png/jpg).
  - Reset App State.
  - Tile Cache size readout and Clear Tile Cache.
  - Tile Cache section appears above Tracks.
  - Diagnostics screen available by long-pressing the Version label.
  - Reset App State clears stored settings (including starred tracks and points) back to defaults; it does not delete library files or the tile cache.
- Error handling & observability
  - GPX parse errors are shown inline; tiles that fail to load surface a non-blocking banner.
  - Basic counters for cache hits/misses/errors shown in a hidden Diagnostics screen.

## Non-Functional Requirements
- Independence from online services: core browsing and track inspection work without network access; only outbound calls are optional tile requests to configured providers (or none when Offline Mode is set).
- Performance: map remains responsive with large libraries; list filtering must feel instant.
- Footprint: Swift/SwiftUI app; minimal third-party dependencies.
- Compatibility: iOS 26+; supports iPhone only.
- Testing: unit tests cover GPX parsing, track stats, base map URLs, and tile cache; UI tests cover tab navigation and settings/base map selection.

## Constraints and Open Questions
- Tile provider rate limits and legal terms must be observed; no throttling built in.
  - Cache eviction is LRU-based with a 1 GB size cap; manual clearing remains available in Settings.

## Suggested Features (Backlog)
- Track details sheet: elevation profile with min/max/total gain/loss, duration, moving time, avg/max speed; scrubbing highlights the point on the map.
- Multi-track overlay: allow multi-select in Tracks to compare tracks on the map with distinct colors and a small legend.
- Organization: tags; filters for tags; bulk rename/delete actions.
- Share/export: share selected tracks as GPX/GeoJSON, optionally ZIP multiple files.
- Offline trip packs: download tiles for a selected bounding box and zoom range; stored in the existing cache.
- Privacy redaction on export: optional radius mask that removes points near a chosen center before sharing.

## Security & Reliability (Summary)
- All file access is restricted to the app sandbox.
- Validate file extensions on import.
