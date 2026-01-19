import Foundation
import CoreLocation

struct TrackStats {
    let distanceKm: Double
    let duration: TimeInterval
    let movingDuration: TimeInterval
    let movingSpeedKmh: Double
    let elevationGain: Double
    let elevationLoss: Double
    let startDate: Date?

    static func compute(points: [TrackPoint]) -> TrackStats {
        guard points.count > 1 else {
            return TrackStats(distanceKm: 0, duration: 0, movingDuration: 0, movingSpeedKmh: 0, elevationGain: 0, elevationLoss: 0, startDate: points.first?.timestamp)
        }

        var distance: CLLocationDistance = 0
        var movingTime: TimeInterval = 0
        var totalTime: TimeInterval = 0

        let speedThreshold: CLLocationSpeed = 0.5
        for idx in 1..<points.count {
            let prev = points[idx - 1]
            let current = points[idx]
            let prevLoc = CLLocation(latitude: prev.coordinate.latitude, longitude: prev.coordinate.longitude)
            let currLoc = CLLocation(latitude: current.coordinate.latitude, longitude: current.coordinate.longitude)
            let segmentDistance = currLoc.distance(from: prevLoc)
            distance += segmentDistance

            if let prevTime = prev.timestamp, let currTime = current.timestamp {
                let delta = currTime.timeIntervalSince(prevTime)
                if delta > 0 {
                    totalTime += delta
                    let speed = segmentDistance / delta
                    if speed >= speedThreshold {
                        movingTime += delta
                    }
                }
            }
        }

        let effectiveMovingTime = movingTime > 0 ? movingTime : totalTime
        let speedKmh = effectiveMovingTime > 0 ? (distance / effectiveMovingTime) * 3.6 : 0

        let elevation = elevationGainLoss(points: points, threshold: 3.0)

        return TrackStats(
            distanceKm: distance / 1000.0,
            duration: totalTime,
            movingDuration: effectiveMovingTime,
            movingSpeedKmh: speedKmh,
            elevationGain: elevation.gain,
            elevationLoss: elevation.loss,
            startDate: points.first?.timestamp
        )
    }

    private static func elevationGainLoss(points: [TrackPoint], threshold: Double) -> (gain: Double, loss: Double) {
        var gain: Double = 0
        var loss: Double = 0
        var lastElevation: Double?

        for point in points {
            guard let elevation = point.elevation else { continue }
            if let last = lastElevation {
                let delta = elevation - last
                if delta > threshold {
                    gain += delta
                } else if delta < -threshold {
                    loss += abs(delta)
                }
            }
            lastElevation = elevation
        }

        return (gain, loss)
    }

    var distanceText: String {
        String(format: "%.2f km", distanceKm)
    }

    var durationText: String {
        formatDuration(duration)
    }

    var movingDurationText: String {
        formatDuration(movingDuration)
    }

    var speedText: String {
        String(format: "%.1f km/h", movingSpeedKmh)
    }

    var elevationText: String {
        String(format: "+%.0f / -%.0f m", elevationGain, elevationLoss)
    }

    var dateText: String {
        guard let startDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "—"
    }
}
