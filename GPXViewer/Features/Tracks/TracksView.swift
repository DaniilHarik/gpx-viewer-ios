import SwiftUI

struct TracksView: View {
    @EnvironmentObject private var tracksStore: TracksStore
    @Binding var selectedTab: Int

    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var pendingDeletion: [GPXFile] = []
    @State private var showingDeleteConfirm = false
    @State private var renamingFile: GPXFile?
    @State private var renameText = ""
    @State private var renameErrorMessage: String?
    @State private var showingRenameError = false

    var body: some View {
        NavigationStack {
            List {
                if tracksStore.isScanning {
                    HStack {
                        ProgressView()
                        Text("Scanning tracks...")
                    }
                }

                if !starredFiles.isEmpty {
                    Section(header: Text("Starred")) {
                        ForEach(starredFiles) { file in
                            TracksRow(
                                file: file,
                                isSelected: tracksStore.selectedFile?.id == file.id,
                                isStarred: true,
                                stats: tracksStore.trackStats[file.url],
                                error: tracksStore.parseErrors[file.url],
                                onSelect: { toggleSelection(for: file) },
                                onToggleStar: { tracksStore.toggleStar(for: file) },
                                onRename: { beginRename(for: file) }
                            )
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                starAction(for: file)
                            }
                        }
                        .onDelete { offsets in
                            confirmDelete(in: starredFiles, offsets: offsets)
                        }
                    }
                }

                ForEach(sectionedFiles.keys.sorted(by: >), id: \.self) { year in
                    Section(header: Text(sectionTitle(for: year))) {
                        ForEach(sectionedFiles[year] ?? []) { file in
                            TracksRow(
                                file: file,
                                isSelected: tracksStore.selectedFile?.id == file.id,
                                isStarred: tracksStore.isStarred(file),
                                stats: tracksStore.trackStats[file.url],
                                error: tracksStore.parseErrors[file.url],
                                onSelect: { toggleSelection(for: file) },
                                onToggleStar: { tracksStore.toggleStar(for: file) },
                                onRename: { beginRename(for: file) }
                            )
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                starAction(for: file)
                            }
                        }
                        .onDelete { offsets in
                            confirmDelete(in: sectionedFiles[year] ?? [], offsets: offsets)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tracks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingImporter = true }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search files")
            .sheet(isPresented: $showingImporter) {
                DocumentPicker { urls in
                    tracksStore.importFiles(urls)
                }
            }
            .alert("Delete Track", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    tracksStore.deleteFiles(pendingDeletion)
                    pendingDeletion = []
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletion = []
                }
            } message: {
                if pendingDeletion.count == 1, let name = pendingDeletion.first?.displayName {
                    Text("This will permanently delete “\(name)” from your tracks.")
                } else {
                    Text("This will permanently delete the selected tracks from your tracks.")
                }
            }
            .alert("Rename Track", isPresented: renamePromptBinding) {
                TextField("Track name", text: $renameText)
                    .textInputAutocapitalization(.words)
                Button("Rename") {
                    commitRename()
                }
                Button("Cancel", role: .cancel) {
                    renamingFile = nil
                }
            } message: {
                if let file = renamingFile {
                    Text("Enter a new name for “\(file.displayName)”.")
                }
            }
            .alert("Rename Failed", isPresented: $showingRenameError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let renameErrorMessage {
                    Text(renameErrorMessage)
                }
            }
        }
    }

    private var filteredFiles: [GPXFile] {
        guard !searchText.isEmpty else { return tracksStore.files }
        let term = searchText.lowercased()
        return tracksStore.files.filter {
            $0.displayName.lowercased().contains(term) || $0.relativePath.lowercased().contains(term)
        }
    }

    private var starredFiles: [GPXFile] {
        filteredFiles.filter { tracksStore.isStarred($0) }
    }

    private var unstarredFiles: [GPXFile] {
        filteredFiles.filter { !tracksStore.isStarred($0) }
    }

    private var sectionedFiles: [Int: [GPXFile]] {
        Dictionary(grouping: unstarredFiles) { $0.year ?? 0 }
    }

    private func sectionTitle(for year: Int) -> String {
        if year == 0 { return "Unknown" }
        return String(year)
    }

    private func toggleSelection(for file: GPXFile) {
        if tracksStore.selectedFile?.id == file.id {
            tracksStore.deselect()
        } else {
            tracksStore.select(file)
            selectedTab = 0
        }
    }

    private func confirmDelete(in files: [GPXFile], offsets: IndexSet) {
        let toDelete = offsets.compactMap { index -> GPXFile? in
            guard files.indices.contains(index) else { return nil }
            return files[index]
        }
        guard !toDelete.isEmpty else { return }
        pendingDeletion = toDelete
        showingDeleteConfirm = true
    }

    private var renamePromptBinding: Binding<Bool> {
        Binding(
            get: { renamingFile != nil },
            set: { newValue in
                if !newValue {
                    renamingFile = nil
                }
            }
        )
    }

    private func beginRename(for file: GPXFile) {
        renamingFile = file
        renameText = file.displayName
        renameErrorMessage = nil
        showingRenameError = false
    }

    private func commitRename() {
        guard let file = renamingFile else { return }
        let proposedName = renameText
        renamingFile = nil

        tracksStore.renameFile(file, to: proposedName) { result in
            if case .failure(let error) = result {
                renameErrorMessage = error.localizedDescription
                showingRenameError = true
            }
        }
    }

    @ViewBuilder
    private func starAction(for file: GPXFile) -> some View {
        if tracksStore.isStarred(file) {
            Button {
                tracksStore.toggleStar(for: file)
            } label: {
                Label("Unstar", systemImage: "star.slash")
            }
            .tint(.gray)
        } else {
            Button {
                tracksStore.toggleStar(for: file)
            } label: {
                Label("Star", systemImage: "star.fill")
            }
            .tint(.yellow)
        }
    }
}

private struct TracksRow: View {
    let file: GPXFile
    let isSelected: Bool
    let isStarred: Bool
    let stats: TrackStats?
    let error: String?
    let onSelect: () -> Void
    let onToggleStar: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.blue : Color.primary)
                if let subtitleText {
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if isStarred {
                    Image(systemName: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.yellow)
                        .accessibilityLabel("Starred")
                }
                if let stats {
                    Text(stats.distanceText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if let error {
                    Text(error)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.red.opacity(0.1))
                        )
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(action: onToggleStar) {
                Label(isStarred ? "Unstar" : "Star", systemImage: isStarred ? "star.slash" : "star.fill")
            }
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
        }
    }

    private var subtitleText: String? {
        TracksRowFormatter.subtitle(for: file)
    }

    private var displayTitle: String {
        TracksRowFormatter.displayTitle(for: file.displayName)
    }
}
