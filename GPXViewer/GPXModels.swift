import Foundation
import MapKit

struct TrackPoint {
    let coordinate: CLLocationCoordinate2D
    let elevation: Double?
    let timestamp: Date?
}

struct GPXTrack: Identifiable {
    let id = UUID()
    let name: String?
    let points: [TrackPoint]
    let bounds: MKMapRect
    let stats: TrackStats
}

struct GPXFile: Identifiable, Hashable {
    let id: URL
    let url: URL
    let displayName: String
    let relativePath: String
    let sortDate: Date?
    let year: Int?
}
