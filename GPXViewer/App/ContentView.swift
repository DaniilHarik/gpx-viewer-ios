import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var tracksStore: TracksStore

    var body: some View {
        TabView(selection: $selectedTab) {
            MapScreen()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(0)

            TracksView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Tracks", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .onOpenURL { url in
            tracksStore.importFiles([url])
            selectedTab = 1
        }
    }
}
