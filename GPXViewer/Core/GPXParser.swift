import Foundation
import MapKit

enum GPXParserError: Error {
    case invalidFile
    case noPoints
}

final class GPXParser: NSObject, XMLParserDelegate {
    private var points: [TrackPoint] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?
    private var currentText: String = ""
    private var currentElement: String?
    private var trackName: String?

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func parse(url: URL) throws -> GPXTrack {
        points = []
        trackName = nil
        currentLat = nil
        currentLon = nil
        currentEle = nil
        currentTime = nil

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
        return GPXTrack(name: trackName, points: points, bounds: bounds, stats: stats)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentText = ""
        currentElement = elementName

        if elementName == "trkpt" {
            currentLat = Double(attributeDict["lat"] ?? "")
            currentLon = Double(attributeDict["lon"] ?? "")
            currentEle = nil
            currentTime = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

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
            if trackName == nil {
                trackName = trimmed
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
        default:
            break
        }

        currentElement = nil
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
