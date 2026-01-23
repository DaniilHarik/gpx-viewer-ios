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

                ForEach(sectionedFiles.keys.sorted(by: >), id: \.self) { year in
                    Section(header: Text(sectionTitle(for: year))) {
                        ForEach(sectionedFiles[year] ?? []) { file in
                            Button(action: { toggleSelection(for: file) }) {
                                LibraryRow(
                                    file: file,
                                    isSelected: libraryStore.selectedFile?.id == file.id,
                                    stats: libraryStore.trackStats[file.url],
                                    error: libraryStore.parseErrors[file.url]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            confirmDelete(in: year, offsets: offsets)
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

    private var sectionedFiles: [Int: [GPXFile]] {
        Dictionary(grouping: filteredFiles) { $0.year ?? 0 }
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

    private func confirmDelete(in year: Int, offsets: IndexSet) {
        guard let files = sectionedFiles[year] else { return }
        let toDelete = offsets.compactMap { index -> GPXFile? in
            guard files.indices.contains(index) else { return nil }
            return files[index]
        }
        guard !toDelete.isEmpty else { return }
        pendingDeletion = toDelete
        showingDeleteConfirm = true
    }
}

private struct LibraryRow: View {
    let file: GPXFile
    let isSelected: Bool
    let stats: TrackStats?
    let error: String?

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
    }

    private var subtitleText: String? {
        if let prefix = datePrefix {
            return prefix
        }
        return file.relativePath
    }

    private var displayTitle: String {
        guard let prefix = datePrefix else { return file.displayName }
        var remainder = String(file.displayName.dropFirst(prefix.count))
        remainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        if remainder.hasPrefix("-") || remainder.hasPrefix("_") {
            remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return remainder.isEmpty ? file.displayName : remainder
    }

    private var datePrefix: String? {
        let name = file.displayName
        guard name.count >= 10 else { return nil }
        let prefix = String(name.prefix(10))
        guard Self.isValidDatePrefix(prefix) else { return nil }
        return prefix
    }

    private static func isValidDatePrefix(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) != nil
    }
}
