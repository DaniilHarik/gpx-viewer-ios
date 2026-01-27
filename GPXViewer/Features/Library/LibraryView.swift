import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @Binding var selectedTab: Int

    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var pendingDeletion: [GPXFile] = []
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                if libraryStore.isScanning {
                    HStack {
                        ProgressView()
                        Text("Scanning library...")
                    }
                }

                if !starredFiles.isEmpty {
                    Section(header: Text("Starred")) {
                        ForEach(starredFiles) { file in
                            LibraryRow(
                                file: file,
                                isSelected: libraryStore.selectedFile?.id == file.id,
                                isStarred: true,
                                stats: libraryStore.trackStats[file.url],
                                error: libraryStore.parseErrors[file.url],
                                onSelect: { toggleSelection(for: file) },
                                onToggleStar: { libraryStore.toggleStar(for: file) }
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
                            LibraryRow(
                                file: file,
                                isSelected: libraryStore.selectedFile?.id == file.id,
                                isStarred: libraryStore.isStarred(file),
                                stats: libraryStore.trackStats[file.url],
                                error: libraryStore.parseErrors[file.url],
                                onSelect: { toggleSelection(for: file) },
                                onToggleStar: { libraryStore.toggleStar(for: file) }
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
            .navigationTitle("Library")
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
                    libraryStore.importFiles(urls)
                }
            }
            .alert("Delete Track", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    libraryStore.deleteFiles(pendingDeletion)
                    pendingDeletion = []
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletion = []
                }
            } message: {
                if pendingDeletion.count == 1, let name = pendingDeletion.first?.displayName {
                    Text("This will permanently delete “\(name)” from your library.")
                } else {
                    Text("This will permanently delete the selected tracks from your library.")
                }
            }
        }
    }

    private var filteredFiles: [GPXFile] {
        guard !searchText.isEmpty else { return libraryStore.files }
        let term = searchText.lowercased()
        return libraryStore.files.filter {
            $0.displayName.lowercased().contains(term) || $0.relativePath.lowercased().contains(term)
        }
    }

    private var starredFiles: [GPXFile] {
        filteredFiles.filter { libraryStore.isStarred($0) }
    }

    private var unstarredFiles: [GPXFile] {
        filteredFiles.filter { !libraryStore.isStarred($0) }
    }

    private var sectionedFiles: [Int: [GPXFile]] {
        Dictionary(grouping: unstarredFiles) { $0.year ?? 0 }
    }

    private func sectionTitle(for year: Int) -> String {
        if year == 0 { return "Unknown" }
        return String(year)
    }

    private func toggleSelection(for file: GPXFile) {
        if libraryStore.selectedFile?.id == file.id {
            libraryStore.deselect()
        } else {
            libraryStore.select(file)
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

    @ViewBuilder
    private func starAction(for file: GPXFile) -> some View {
        if libraryStore.isStarred(file) {
            Button {
                libraryStore.toggleStar(for: file)
            } label: {
                Label("Unstar", systemImage: "star.slash")
            }
            .tint(.gray)
        } else {
            Button {
                libraryStore.toggleStar(for: file)
            } label: {
                Label("Star", systemImage: "star.fill")
            }
            .tint(.yellow)
        }
    }
}

private struct LibraryRow: View {
    let file: GPXFile
    let isSelected: Bool
    let isStarred: Bool
    let stats: TrackStats?
    let error: String?
    let onSelect: () -> Void
    let onToggleStar: () -> Void

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
        }
    }

    private var subtitleText: String? {
        LibraryRowFormatter.subtitle(for: file)
    }

    private var displayTitle: String {
        LibraryRowFormatter.displayTitle(for: file.displayName)
    }
}
