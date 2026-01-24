import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var bannerCenter: BannerCenter

    @State private var followUser = false
    @State private var showUserLocation = false
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
                HStack(alignment: .bottom) {
                    MeasurementControlView(
                        measurementEnabled: measurementEnabled,
                        buttonSize: controlButtonSize,
                        summaryText: measurementSummaryText,
                        pointCount: measurementPoints.count,
                        onToggle: toggleMeasurement,
                        onUndo: {
                            if measurementPoints.count > 1 {
                                measurementPoints.removeLast()
                            }
                        },
                        onClear: { measurementPoints.removeAll() }
                    )
                    .padding(.leading, 16)
                    .padding(.bottom, buttonBottomPadding)

                    Spacer()
                    Button(action: toggleFollow) {
                        Image(systemName: followUser ? "location.fill" : "location")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(followUser ? .blue : .primary)
                            .frame(width: controlButtonSize, height: controlButtonSize)
                            .background(
                                Circle().fill(Color(UIColor.systemBackground))
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
    }

    private var buttonBottomPadding: CGFloat {
        16
    }

    private var controlButtonSize: CGFloat {
        46
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

private struct MeasurementControlView: View {
    let measurementEnabled: Bool
    let buttonSize: CGFloat
    let summaryText: String
    let pointCount: Int
    let onToggle: () -> Void
    let onUndo: () -> Void
    let onClear: () -> Void

    var body: some View {
        if measurementEnabled {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.orange)
                        .frame(width: buttonSize, height: buttonSize)
                }
                .accessibilityLabel("Disable measurement")

                Text(summaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)

                if pointCount > 0 {
                    HStack(spacing: 6) {
                        if pointCount > 1 {
                            Button(action: onUndo) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .frame(width: 26, height: 26)
                            }
                            .accessibilityLabel("Undo last segment")
                        }

                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.orange)
                                .frame(width: 26, height: 26)
                        }
                        .accessibilityLabel("Clear measurement")
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color(UIColor.systemBackground))
            )
            .shadow(radius: 6)
        } else {
            Button(action: onToggle) {
                Image(systemName: "ruler")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(
                        Circle().fill(Color(UIColor.systemBackground))
                    )
                    .shadow(radius: 6)
            }
            .buttonStyle(.plain)
            .tint(.primary)
            .accessibilityLabel("Enable measurement")
        }
    }
}
