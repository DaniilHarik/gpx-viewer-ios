import CoreLocation
import Foundation
import XCTest
@testable import GPXViewer

final class TrackStatsTests: XCTestCase {
    func testComputeUsesMovingTimeWhenAboveThreshold() {
        let start = Date(timeIntervalSince1970: 0)
        let points = [
            TrackPoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), elevation: 0, timestamp: start),
            TrackPoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0.001), elevation: 5, timestamp: start.addingTimeInterval(100)),
            TrackPoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0.001), elevation: 1, timestamp: start.addingTimeInterval(200))
        ]

        let stats = TrackStats.compute(points: points)

        let segmentDistance = CLLocation(latitude: 0, longitude: 0)
            .distance(from: CLLocation(latitude: 0, longitude: 0.001))
        let expectedDistanceKm = segmentDistance / 1000.0
        let expectedSpeed = (segmentDistance / 100.0) * 3.6

        XCTAssertEqual(stats.distanceKm, expectedDistanceKm, accuracy: 0.001)
        XCTAssertEqual(stats.duration, 200, accuracy: 0.1)
        XCTAssertEqual(stats.movingDuration, 100, accuracy: 0.1)
        XCTAssertEqual(stats.movingSpeedKmh, expectedSpeed, accuracy: 0.1)
        XCTAssertEqual(stats.elevationGain, 5, accuracy: 0.01)
        XCTAssertEqual(stats.elevationLoss, 4, accuracy: 0.01)
        XCTAssertEqual(stats.startDate, start)
    }

    func testComputeFallsBackToTotalTimeWhenStationary() {
        let start = Date(timeIntervalSince1970: 0)
        let points = [
            TrackPoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), elevation: nil, timestamp: start),
            TrackPoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), elevation: nil, timestamp: start.addingTimeInterval(60))
        ]

        let stats = TrackStats.compute(points: points)

        XCTAssertEqual(stats.distanceKm, 0, accuracy: 0.0001)
        XCTAssertEqual(stats.duration, 60, accuracy: 0.1)
        XCTAssertEqual(stats.movingDuration, 60, accuracy: 0.1)
        XCTAssertEqual(stats.movingSpeedKmh, 0, accuracy: 0.1)
    }

    func testElevationGainLossIgnoresSmallChanges() {
        let start = Date(timeIntervalSince1970: 0)
        let points = [
            TrackPoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), elevation: 10, timestamp: start),
            TrackPoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0.001), elevation: 12, timestamp: start.addingTimeInterval(10)),
            TrackPoint(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0.002), elevation: 15, timestamp: start.addingTimeInterval(20))
        ]

        let stats = TrackStats.compute(points: points)

        XCTAssertEqual(stats.elevationGain, 0, accuracy: 0.01)
        XCTAssertEqual(stats.elevationLoss, 0, accuracy: 0.01)
    }
}
