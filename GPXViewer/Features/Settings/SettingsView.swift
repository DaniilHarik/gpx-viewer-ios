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
                    Toggle("Distance Markers", isOn: $settings.distanceMarkersEnabled)
                    Picker("Marker Interval", selection: $settings.distanceMarkerInterval) {
                        ForEach(DistanceMarkerInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!settings.distanceMarkersEnabled)

                    NavigationLink {
                        BaseMapSelectionView(selectedId: $settings.baseMapId, providers: settings.tileProviders)
                    } label: {
                        HStack {
                            Text("Default Base Map")
                            Spacer()
                            Text(settings.baseMap.title)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        TileProvidersView()
                    } label: {
                        HStack {
                            Text("Tile Providers")
                            Spacer()
                            Text("\(settings.tileProviders.count)")
                                .foregroundStyle(.secondary)
                        }
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

                Section(header: Text("Library")) {
                    Button("Reset App State", role: .destructive) {
                        showResetConfirm = true
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
                    libraryStore.resetStarred()
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
    @Binding var selectedId: String
    let providers: [BaseMapProvider]

    var body: some View {
        List {
            ForEach(providers) { provider in
                Button(action: { selectedId = provider.id }) {
                    HStack {
                        Text(provider.title)
                        Spacer()
                        if provider.id == selectedId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Base Map")
    }
}

private struct TileProvidersView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showAdd = false
    @State private var newProvider = BaseMapProvider.newCustom()

    var body: some View {
        List {
            Section {
                ForEach($settings.tileProviders) { $provider in
                    NavigationLink {
                        TileProviderEditorView(
                            provider: $provider,
                            title: "Edit Provider",
                            showsToolbar: false,
                            onSave: nil,
                            onCancel: nil
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.title)
                            Text(provider.urlTemplate)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .onDelete(perform: deleteProviders)
            } footer: {
                Text("Add, edit, or remove tile providers used for base maps.")
            }
        }
        .navigationTitle("Tile Providers")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: beginAdd) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                TileProviderEditorView(
                    provider: $newProvider,
                    title: "New Provider",
                    showsToolbar: true,
                    onSave: saveNewProvider,
                    onCancel: cancelNewProvider
                )
            }
        }
    }

    private func beginAdd() {
        newProvider = BaseMapProvider.newCustom()
        showAdd = true
    }

    private func saveNewProvider() {
        settings.tileProviders.append(newProvider)
        showAdd = false
        newProvider = BaseMapProvider.newCustom()
    }

    private func cancelNewProvider() {
        showAdd = false
        newProvider = BaseMapProvider.newCustom()
    }

    private func deleteProviders(at offsets: IndexSet) {
        guard settings.tileProviders.count > 1 else { return }
        settings.tileProviders.remove(atOffsets: offsets)
        if settings.tileProviders.isEmpty {
            settings.tileProviders = BaseMapProvider.builtInProviders()
        }
    }
}

private struct TileProviderEditorView: View {
    @Binding var provider: BaseMapProvider
    let title: String
    let showsToolbar: Bool
    let onSave: (() -> Void)?
    let onCancel: (() -> Void)?

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $provider.name)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Template URL")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $provider.urlTemplate)
                        .frame(minHeight: 96)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Details")
            } footer: {
                Text("Use {z}, {x}, and {y} placeholders for tile coordinates.")
            }

            Section {
                Stepper(value: $provider.maxZoom, in: 0...22) {
                    HStack {
                        Text("Max Zoom")
                        Spacer()
                        Text("\(provider.maxZoom)")
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("TMS Y-Axis", isOn: $provider.usesTMS)

                Picker("File Type", selection: $provider.tileFileExtension) {
                    Text("PNG").tag("png")
                    Text("JPG").tag("jpg")
                }
            } header: {
                Text("Rendering")
            }
        }
        .navigationTitle(title)
        .toolbar {
            if showsToolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel?()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave?()
                    }
                }
            }
        }
    }
}
