import Foundation
import MapKit

struct TrackPoint {
    let coordinate: CLLocationCoordinate2D
    let elevation: Double?
    let timestamp: Date?
}

struct GPXWaypoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String?
    let description: String?
}

struct GPXTrack: Identifiable {
    let id = UUID()
    let name: String?
    let points: [TrackPoint]
    let waypoints: [GPXWaypoint]
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
