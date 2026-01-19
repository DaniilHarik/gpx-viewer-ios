import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var showResetConfirm = false
    @State private var showCacheConfirm = false
    @State private var showDiagnostics = false
    @State private var cacheSizeText = "Calculating..."

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(ThemeSetting.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Map")) {
                    Toggle("Offline Mode", isOn: $settings.offlineMode)
                    Toggle("1 km Distance Markers", isOn: $settings.distanceMarkersEnabled)

                    NavigationLink {
                        BaseMapSelectionView(selected: $settings.baseMap)
                    } label: {
                        HStack {
                            Text("Default Base Map")
                            Spacer()
                            Text(settings.baseMap.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("Library")) {
                    Button("Rescan Library") {
                        libraryStore.scanDocuments()
                    }

                    Button("Reset App State", role: .destructive) {
                        showResetConfirm = true
                    }
                }

                Section(header: Text("Tile Cache")) {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(cacheSizeText)
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear Tile Cache") {
                        showCacheConfirm = true
                    }
                }

                Section {
                    Text("Version 1.0")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onLongPressGesture {
                            showDiagnostics = true
                        }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .confirmationDialog("Reset app state?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) {
                    settings.reset()
                    libraryStore.scanDocuments()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Clear tile cache?", isPresented: $showCacheConfirm) {
                Button("Clear", role: .destructive) {
                    TileCache.shared.clearAll {
                        refreshCacheSize()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .navigationDestination(isPresented: $showDiagnostics) {
                DiagnosticsView()
            }
            .task {
                refreshCacheSize()
            }
        }
    }

    private func refreshCacheSize() {
        TileCache.shared.currentSize { size in
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            cacheSizeText = formatter.string(fromByteCount: size)
        }
    }
}

private struct BaseMapSelectionView: View {
    @Binding var selected: BaseMapProvider

    var body: some View {
        List {
            ForEach(BaseMapProvider.allCases) { provider in
                Button(action: { selected = provider }) {
                    HStack {
                        Text(provider.title)
                        Spacer()
                        if provider == selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Base Map")
    }
}
