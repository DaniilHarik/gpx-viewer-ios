import Foundation
import MapKit

struct SavedPoint: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var iconName: String
    var latitude: Double
    var longitude: Double
    var isStarred: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

final class PointsStore: ObservableObject {
    @Published private(set) var points: [SavedPoint] = [] {
        didSet { persistPoints() }
    }
    @Published var selectedPoint: SavedPoint?

    private let pointsKey = "savedPoints"
    private var isLoading = false

    init() {
        loadPoints()
    }

    func addPoint(title: String, iconName: String, latitude: Double, longitude: Double) {
        let point = SavedPoint(
            id: UUID(),
            title: title,
            iconName: iconName,
            latitude: latitude,
            longitude: longitude,
            isStarred: false
        )
        points.append(point)
    }

    func deletePoints(_ pointsToDelete: [SavedPoint]) {
        guard !pointsToDelete.isEmpty else { return }
        let ids = Set(pointsToDelete.map { $0.id })
        points.removeAll { ids.contains($0.id) }
        if let selected = selectedPoint, ids.contains(selected.id) {
            selectedPoint = nil
        }
    }

    func toggleStar(for point: SavedPoint) {
        guard let index = points.firstIndex(where: { $0.id == point.id }) else { return }
        points[index].isStarred.toggle()
        if selectedPoint?.id == point.id {
            selectedPoint = points[index]
        }
    }

    func updatePoint(_ point: SavedPoint, title: String, iconName: String, latitude: Double, longitude: Double) {
        guard let index = points.firstIndex(where: { $0.id == point.id }) else { return }
        points[index].title = title
        points[index].iconName = iconName
        points[index].latitude = latitude
        points[index].longitude = longitude
        if selectedPoint?.id == point.id {
            selectedPoint = points[index]
        }
    }

    func select(_ point: SavedPoint) {
        if let stored = points.first(where: { $0.id == point.id }) {
            selectedPoint = stored
        } else {
            selectedPoint = point
        }
    }

    func deselect() {
        selectedPoint = nil
    }

    func reset() {
        points = []
        selectedPoint = nil
    }

    private func loadPoints() {
        isLoading = true
        defer { isLoading = false }

        guard let data = UserDefaults.standard.data(forKey: pointsKey),
              let decoded = try? JSONDecoder().decode([SavedPoint].self, from: data) else {
            points = []
            return
        }
        points = decoded
    }

    private func persistPoints() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder().encode(points) else { return }
        UserDefaults.standard.set(data, forKey: pointsKey)
    }
}
