import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var libraryStore: LibraryStore

    var body: some View {
        TabView(selection: $selectedTab) {
            MapScreen()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(0)

            LibraryView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Library", systemImage: "list.bullet")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .onOpenURL { url in
            libraryStore.importFiles([url])
            selectedTab = 1
        }
    }
}
