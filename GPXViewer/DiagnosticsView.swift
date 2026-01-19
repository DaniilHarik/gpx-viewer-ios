import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject private var stats = TileCache.shared.stats

    var body: some View {
        List {
            Section(header: Text("Tile Cache")) {
                DiagnosticRow(title: "Hits", value: String(stats.hits))
                DiagnosticRow(title: "Misses", value: String(stats.misses))
                DiagnosticRow(title: "Errors", value: String(stats.errors))
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DiagnosticRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
