import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var bannerCenter: BannerCenter

    @State private var followUser = false
    @State private var showUserLocation = false
    @State private var showInfoPanel = false
    @State private var measurementEnabled = false
    @State private var measurementPoints: [CLLocationCoordinate2D] = []

    var body: some View {
        ZStack(alignment: .top) {
            MapView(
                track: libraryStore.currentTrack,
                provider: settings.baseMap,
                offlineMode: settings.offlineMode,
                showsDistanceMarkers: settings.distanceMarkersEnabled,
                distanceMarkerIntervalKm: settings.distanceMarkerInterval.rawValue,
                followUser: followUser,
                showsUserLocation: showUserLocation,
                userHeading: locationManager.heading,
                measurementPoints: measurementPoints,
                measurementEnabled: measurementEnabled,
                onUserInteraction: {
                    if followUser {
                        followUser = false
                    }
                },
                onMeasureTap: { coordinate in
                    measurementPoints.append(coordinate)
                }
            )
            .ignoresSafeArea()

            if let message = bannerCenter.message {
                BannerView(text: message)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 8) {
                if measurementEnabled {
                    MeasurementSummaryView(
                        summaryText: measurementSummaryText,
                        pointCount: measurementPoints.count,
                        onUndo: {
                            if measurementPoints.count > 1 {
                                measurementPoints.removeLast()
                            }
                        },
                        onClear: { measurementPoints.removeAll() }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let track = libraryStore.currentTrack, showInfoPanel {
                    TrackInfoView(stats: track.stats)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, bannerCenter.message == nil ? 12 : 64)

            if let attribution = settings.baseMap.attributionText {
                VStack {
                    Spacer()
                    AttributionView(text: attribution)
                        .padding(.bottom, libraryStore.currentTrack == nil ? 12 : 96)
                        .padding(.horizontal, 12)
                }
            }

            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 12) {
                        if libraryStore.currentTrack != nil {
                            Button(action: { showInfoPanel.toggle() }) {
                                Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(14)
                                    .background(
                                        Circle().fill(Color.black.opacity(0.75))
                                    )
                                    .shadow(radius: 6)
                            }
                        }

                        Button(action: toggleMeasurement) {
                            Image(systemName: measurementEnabled ? "ruler.fill" : "ruler")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(
                                    Circle().fill(Color.black.opacity(0.75))
                                )
                                .shadow(radius: 6)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, buttonBottomPadding)

                    Spacer()
                    Button(action: toggleFollow) {
                        Image(systemName: followUser ? "location.fill" : "location")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(
                                Circle().fill(Color.black.opacity(0.75))
                            ) 
                            .shadow(radius: 6)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, buttonBottomPadding)
                }
            }
        }
        .onChange(of: locationManager.isAuthorized) { newValue in
            if !newValue {
                followUser = false
                showUserLocation = false
            } else if showUserLocation {
                locationManager.startUpdating()
            }
        }
        .onChange(of: libraryStore.currentTrack?.id) { _ in
            showInfoPanel = false
        }
    }

    private var buttonBottomPadding: CGFloat {
        16
    }

    private var measurementSummaryText: String {
        if measurementPoints.isEmpty {
            return "Tap map to add points"
        }
        if measurementPoints.count == 1 {
            return "Tap another point"
        }
        return measurementDistanceText
    }

    private var measurementDistanceText: String {
        let distance = measurementDistance
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        }
        return String(format: "%.2f km", distance / 1000.0)
    }

    private var measurementDistance: CLLocationDistance {
        guard measurementPoints.count > 1 else { return 0 }
        var distance: CLLocationDistance = 0
        var previous = measurementPoints[0]
        for coordinate in measurementPoints.dropFirst() {
            let prevLoc = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
            let currLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            distance += currLoc.distance(from: prevLoc)
            previous = coordinate
        }
        return distance
    }

    private func toggleFollow() {
        if followUser {
            followUser = false
            return
        }

        locationManager.requestWhenInUse()
        locationManager.startUpdating()
        followUser = true
        showUserLocation = true
    }

    private func toggleMeasurement() {
        measurementEnabled.toggle()
    }
}

private struct MeasurementSummaryView: View {
    let summaryText: String
    let pointCount: Int
    let onUndo: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Measure")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(summaryText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            if pointCount > 0 {
                HStack(spacing: 8) {
                    if pointCount > 1 {
                        Button(action: onUndo) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel("Undo last segment")
                    }

                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Clear measurement")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(Color.black.opacity(0.75))
        )
        .shadow(radius: 6)
    }
}
