import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var searchText = ""
    @State private var showingImporter = false

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
                                LibraryRow(file: file, isSelected: libraryStore.selectedFile?.id == file.id, error: libraryStore.parseErrors[file.url])
                            }
                            .buttonStyle(.plain)
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
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search files")
            .sheet(isPresented: $showingImporter) {
                DocumentPicker { urls in
                    libraryStore.importFiles(urls)
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
        }
    }
}

private struct LibraryRow: View {
    let file: GPXFile
    let isSelected: Bool
    let error: String?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.blue : Color.primary)
                Text(file.relativePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
        .padding(.vertical, 4)
    }
}
