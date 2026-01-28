import SwiftUI

@main
struct GPXViewerApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var tracksStore = TracksStore()
    @StateObject private var pointsStore = PointsStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var bannerCenter = BannerCenter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(tracksStore)
                .environmentObject(pointsStore)
                .environmentObject(locationManager)
                .environmentObject(bannerCenter)
                .preferredColorScheme(settings.colorScheme)
        }
    }
}
