import SwiftUI

@main
struct GPXViewerApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var libraryStore = LibraryStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var bannerCenter = BannerCenter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(libraryStore)
                .environmentObject(locationManager)
                .environmentObject(bannerCenter)
                .preferredColorScheme(settings.colorScheme)
        }
    }
}
