import Foundation
import MapKit

enum GPXParserError: Error {
    case invalidFile
    case noPoints
}

final class GPXParser: NSObject, XMLParserDelegate {
    private var points: [TrackPoint] = []
    private var waypoints: [GPXWaypoint] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?
    private var currentWaypointLat: Double?
    private var currentWaypointLon: Double?
    private var currentWaypointName: String?
    private var currentWaypointDescription: String?
    private var currentText: String = ""
    private var trackName: String?
    private var elementStack: [String] = []

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func parse(url: URL) throws -> GPXTrack {
        points = []
        waypoints = []
        trackName = nil
        currentLat = nil
        currentLon = nil
        currentEle = nil
        currentTime = nil
        currentWaypointLat = nil
        currentWaypointLon = nil
        currentWaypointName = nil
        currentWaypointDescription = nil
        elementStack = []

        guard let parser = XMLParser(contentsOf: url) else {
            throw GPXParserError.invalidFile
        }
        parser.delegate = self
        let success = parser.parse()
        if !success {
            throw parser.parserError ?? GPXParserError.invalidFile
        }

        guard !points.isEmpty else {
            throw GPXParserError.noPoints
        }

        let bounds = calculateBounds(points: points)
        let stats = TrackStats.compute(points: points)
        return GPXTrack(name: trackName, points: points, waypoints: waypoints, bounds: bounds, stats: stats)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentText = ""
        elementStack.append(elementName)

        if elementName == "trkpt" {
            currentLat = Double(attributeDict["lat"] ?? "")
            currentLon = Double(attributeDict["lon"] ?? "")
            currentEle = nil
            currentTime = nil
        }

        if elementName == "wpt" {
            currentWaypointLat = Double(attributeDict["lat"] ?? "")
            currentWaypointLon = Double(attributeDict["lon"] ?? "")
            currentWaypointName = nil
            currentWaypointDescription = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parentElement = elementStack.dropLast().last

        switch elementName {
        case "ele":
            currentEle = Double(trimmed)
        case "time":
            if let date = dateFormatter.date(from: trimmed) {
                currentTime = date
            } else {
                currentTime = ISO8601DateFormatter().date(from: trimmed)
            }
        case "name":
            if parentElement == "wpt" {
                currentWaypointName = trimmed.isEmpty ? nil : trimmed
            } else if parentElement == "trk" {
                if !trimmed.isEmpty {
                    trackName = trimmed
                }
            } else if parentElement == "metadata", trackName == nil {
                trackName = trimmed.isEmpty ? nil : trimmed
            }
        case "desc":
            if parentElement == "wpt" {
                currentWaypointDescription = trimmed.isEmpty ? nil : trimmed
            }
        case "trkpt":
            if let lat = currentLat, let lon = currentLon {
                let point = TrackPoint(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), elevation: currentEle, timestamp: currentTime)
                points.append(point)
            }
            currentLat = nil
            currentLon = nil
            currentEle = nil
            currentTime = nil
        case "wpt":
            if let lat = currentWaypointLat, let lon = currentWaypointLon {
                let waypoint = GPXWaypoint(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    name: currentWaypointName,
                    description: currentWaypointDescription
                )
                waypoints.append(waypoint)
            }
            currentWaypointLat = nil
            currentWaypointLon = nil
            currentWaypointName = nil
            currentWaypointDescription = nil
        default:
            break
        }

        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
    }

    private func calculateBounds(points: [TrackPoint]) -> MKMapRect {
        guard let first = points.first else { return .null }
        var minLat = first.coordinate.latitude
        var maxLat = first.coordinate.latitude
        var minLon = first.coordinate.longitude
        var maxLon = first.coordinate.longitude

        for point in points {
            minLat = min(minLat, point.coordinate.latitude)
            maxLat = max(maxLat, point.coordinate.latitude)
            minLon = min(minLon, point.coordinate.longitude)
            maxLon = max(maxLon, point.coordinate.longitude)
        }

        let topLeft = MKMapPoint(CLLocationCoordinate2D(latitude: maxLat, longitude: minLon))
        let bottomRight = MKMapPoint(CLLocationCoordinate2D(latitude: minLat, longitude: maxLon))

        return MKMapRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(topLeft.x - bottomRight.x),
            height: abs(topLeft.y - bottomRight.y)
        )
    }
}
