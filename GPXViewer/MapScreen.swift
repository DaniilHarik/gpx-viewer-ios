import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var bannerCenter: BannerCenter

    @State private var followUser = false
    @State private var showInfoPanel = false

    var body: some View {
        ZStack(alignment: .top) {
            MapView(
                track: libraryStore.currentTrack,
                provider: settings.baseMap,
                offlineMode: settings.offlineMode,
                followUser: followUser,
                showsUserLocation: followUser,
                onUserInteraction: {
                    if followUser {
                        followUser = false
                        locationManager.stopUpdating()
                    }
                }
            )
            .ignoresSafeArea()

            if let message = bannerCenter.message {
                BannerView(text: message)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack {
                Spacer()

                if let track = libraryStore.currentTrack, showInfoPanel {
                    TrackInfoView(stats: track.stats)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
                HStack {
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
                        .padding(.leading, 16)
                        .padding(.bottom, buttonBottomPadding)
                    }

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
            } else if followUser {
                locationManager.startUpdating()
            }
        }
        .onChange(of: libraryStore.currentTrack?.id) { _ in
            showInfoPanel = false
        }
    }

    private var buttonBottomPadding: CGFloat {
        (libraryStore.currentTrack != nil && showInfoPanel) ? 96 : 16
    }

    private func toggleFollow() {
        if followUser {
            followUser = false
            locationManager.stopUpdating()
            return
        }

        locationManager.requestWhenInUse()
        locationManager.startUpdating()
        followUser = true
    }
}
