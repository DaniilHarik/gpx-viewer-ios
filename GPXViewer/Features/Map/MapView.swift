import MapKit
import SwiftUI
import UIKit

struct MapView: UIViewRepresentable {
    let track: GPXTrack?
    let provider: BaseMapProvider
    let offlineMode: Bool
    let showsDistanceMarkers: Bool
    let distanceMarkerIntervalKm: Int
    let followUser: Bool
    let showsUserLocation: Bool
    let userHeading: CLHeading?
    let measurementPoints: [CLLocationCoordinate2D]
    let measurementEnabled: Bool
    let onUserInteraction: () -> Void
    let onMeasureTap: (CLLocationCoordinate2D) -> Void
    let onTrackRendered: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsScale = true
        mapView.showsCompass = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = showsUserLocation

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.userDidInteract(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.userDidInteract(_:)))
        pinchGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(pinchGesture)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.delegate = context.coordinator
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)

        updateTileOverlay(on: mapView, coordinator: context.coordinator)
        updatePolyline(on: mapView, coordinator: context.coordinator)
        updateMeasurementOverlay(on: mapView, coordinator: context.coordinator)
        updateDistanceMarkers(on: mapView, coordinator: context.coordinator)
        updateTracking(on: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.showsUserLocation = showsUserLocation
        mapView.isPitchEnabled = false
        updateTileOverlay(on: mapView, coordinator: context.coordinator)
        updatePolyline(on: mapView, coordinator: context.coordinator)
        updateMeasurementOverlay(on: mapView, coordinator: context.coordinator)
        updateDistanceMarkers(on: mapView, coordinator: context.coordinator)
        updateTracking(on: mapView)
        context.coordinator.userHeading = userHeading
        context.coordinator.updateUserHeading(on: mapView)
    }

    private func updateTileOverlay(on mapView: MKMapView, coordinator: Coordinator) {
        if coordinator.currentProvider != provider {
            if let overlay = coordinator.tileOverlay {
                mapView.removeOverlay(overlay)
            }
            let overlay = CachedTileOverlay(provider: provider, offlineMode: offlineMode)
            overlay.canReplaceMapContent = true
            overlay.maximumZ = provider.maxZoom
            coordinator.tileOverlay = overlay
            coordinator.currentProvider = provider
            mapView.addOverlay(overlay, level: .aboveLabels)
            if let polyline = coordinator.polyline {
                mapView.removeOverlay(polyline)
                mapView.addOverlay(polyline, level: .aboveLabels)
            }
            if let measurementPolyline = coordinator.measurementPolyline {
                mapView.removeOverlay(measurementPolyline)
                mapView.addOverlay(measurementPolyline, level: .aboveLabels)
            }
        } else {
            coordinator.tileOverlay?.offlineMode = offlineMode
        }
    }

    private func updatePolyline(on mapView: MKMapView, coordinator: Coordinator) {
        guard let track = track else {
            if let polyline = coordinator.polyline {
                mapView.removeOverlay(polyline)
                coordinator.polyline = nil
                coordinator.trackID = nil
            }
            coordinator.pendingTrackRenderID = nil
            return
        }

        if coordinator.trackID == track.id {
            return
        }

        if let polyline = coordinator.polyline {
            mapView.removeOverlay(polyline)
        }

        let coords = track.points.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        coordinator.polyline = polyline
        coordinator.trackID = track.id
        coordinator.pendingTrackRenderID = track.id
        mapView.addOverlay(polyline, level: .aboveLabels)

        if !track.bounds.isNull {
            let padding = UIEdgeInsets(top: 120, left: 40, bottom: 180, right: 40)
            mapView.setVisibleMapRect(track.bounds, edgePadding: padding, animated: true)
        }
    }

    private func updateDistanceMarkers(on mapView: MKMapView, coordinator: Coordinator) {
        guard showsDistanceMarkers, let track = track else {
            if !coordinator.distanceMarkers.isEmpty {
                mapView.removeAnnotations(coordinator.distanceMarkers)
                coordinator.distanceMarkers.removeAll()
            }
            coordinator.distanceMarkersTrackID = nil
            coordinator.distanceMarkersEnabled = showsDistanceMarkers
            return
        }

        if coordinator.distanceMarkersTrackID == track.id,
           coordinator.distanceMarkersEnabled == showsDistanceMarkers,
           coordinator.distanceMarkersIntervalKm == distanceMarkerIntervalKm {
            return
        }

        if !coordinator.distanceMarkers.isEmpty {
            mapView.removeAnnotations(coordinator.distanceMarkers)
        }

        let annotations = buildDistanceMarkers(for: track.points, intervalKm: distanceMarkerIntervalKm)
        coordinator.distanceMarkers = annotations
        coordinator.distanceMarkersTrackID = track.id
        coordinator.distanceMarkersEnabled = showsDistanceMarkers
        coordinator.distanceMarkersIntervalKm = distanceMarkerIntervalKm
        if !annotations.isEmpty {
            mapView.addAnnotations(annotations)
        }
    }

    private func buildDistanceMarkers(for points: [TrackPoint], intervalKm: Int) -> [DistanceMarkerAnnotation] {
        guard points.count > 1 else { return [] }
        let sanitizedInterval = max(1, intervalKm)
        let intervalDistance = CLLocationDistance(sanitizedInterval) * 1000
        var markers: [DistanceMarkerAnnotation] = []
        var distanceSoFar: CLLocationDistance = 0
        var nextMarkerDistance: CLLocationDistance = intervalDistance
        var previous = points[0]

        for point in points.dropFirst() {
            let prevLoc = CLLocation(latitude: previous.coordinate.latitude, longitude: previous.coordinate.longitude)
            let currLoc = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
            let segmentDistance = currLoc.distance(from: prevLoc)

            if segmentDistance <= 0 {
                previous = point
                continue
            }

            while distanceSoFar + segmentDistance >= nextMarkerDistance {
                let remaining = nextMarkerDistance - distanceSoFar
                let fraction = remaining / segmentDistance
                let coordinate = interpolateCoordinate(from: previous.coordinate, to: point.coordinate, fraction: fraction)
                let kmValue = Int(nextMarkerDistance / 1000)
                markers.append(DistanceMarkerAnnotation(coordinate: coordinate, kmValue: kmValue))
                nextMarkerDistance += intervalDistance
            }

            distanceSoFar += segmentDistance
            previous = point
        }

        return markers
    }

    private func updateMeasurementOverlay(on mapView: MKMapView, coordinator: Coordinator) {
        guard measurementEnabled, !measurementPoints.isEmpty else {
            if let polyline = coordinator.measurementPolyline {
                mapView.removeOverlay(polyline)
                coordinator.measurementPolyline = nil
            }
            if !coordinator.measurementPointAnnotations.isEmpty {
                mapView.removeAnnotations(coordinator.measurementPointAnnotations)
                coordinator.measurementPointAnnotations.removeAll()
            }
            coordinator.measurementPointCount = 0
            coordinator.measurementLastCoordinate = nil
            coordinator.measurementEnabled = measurementEnabled
            return
        }

        let lastCoordinate = measurementPoints[measurementPoints.count - 1]
        if coordinator.measurementPointCount == measurementPoints.count,
           coordinator.measurementEnabled == measurementEnabled,
           let previousLast = coordinator.measurementLastCoordinate,
           coordinatesMatch(previousLast, lastCoordinate) {
            return
        }

        if let polyline = coordinator.measurementPolyline {
            mapView.removeOverlay(polyline)
        }
        if !coordinator.measurementPointAnnotations.isEmpty {
            mapView.removeAnnotations(coordinator.measurementPointAnnotations)
        }

        if measurementPoints.count > 1 {
            let polyline = MKPolyline(coordinates: measurementPoints, count: measurementPoints.count)
            coordinator.measurementPolyline = polyline
            mapView.addOverlay(polyline, level: .aboveLabels)
        } else {
            coordinator.measurementPolyline = nil
        }

        let annotations = measurementPoints.map { MeasurementPointAnnotation(coordinate: $0) }
        coordinator.measurementPointAnnotations = annotations
        if !annotations.isEmpty {
            mapView.addAnnotations(annotations)
        }

        coordinator.measurementPointCount = measurementPoints.count
        coordinator.measurementLastCoordinate = lastCoordinate
        coordinator.measurementEnabled = measurementEnabled
    }

    private func interpolateCoordinate(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        let latitude = start.latitude + (end.latitude - start.latitude) * fraction
        let longitude = start.longitude + (end.longitude - start.longitude) * fraction
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func coordinatesMatch(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }

    private func updateTracking(on mapView: MKMapView) {
        let mode: MKUserTrackingMode = followUser ? .follow : .none
        if mapView.userTrackingMode != mode {
            mapView.setUserTrackingMode(mode, animated: true)
        }
    }
}

final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
    var parent: MapView
    var tileOverlay: CachedTileOverlay?
    var polyline: MKPolyline?
    var trackID: UUID?
    var currentProvider: BaseMapProvider?
    var distanceMarkers: [MKAnnotation] = []
    var distanceMarkersTrackID: UUID?
    var distanceMarkersEnabled = false
    var distanceMarkersIntervalKm = 1
    var measurementPolyline: MKPolyline?
    var measurementPointAnnotations: [MKAnnotation] = []
    var measurementPointCount = 0
    var measurementLastCoordinate: CLLocationCoordinate2D?
    var measurementEnabled = false
    var userHeading: CLHeading?
    var pendingTrackRenderID: UUID?
    var lastRenderedTrackID: UUID?
    private var userInteracting = false

    init(parent: MapView) {
        self.parent = parent
    }

    @objc func userDidInteract(_ gesture: UIGestureRecognizer) {
        if gesture.state == .began {
            userInteracting = true
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        guard parent.measurementEnabled else { return }
        guard let mapView = gesture.view as? MKMapView else { return }
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        parent.onMeasureTap(coordinate)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if userInteracting {
            userInteracting = false
            parent.onUserInteraction()
        }
    }

    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        guard let pendingTrackRenderID else { return }
        if lastRenderedTrackID == pendingTrackRenderID {
            self.pendingTrackRenderID = nil
            return
        }
        lastRenderedTrackID = pendingTrackRenderID
        self.pendingTrackRenderID = nil
        parent.onTrackRendered(pendingTrackRenderID)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let tileOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: tileOverlay)
        }

        if let polyline = overlay as? MKPolyline {
            if polyline === measurementPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemOrange
                renderer.lineWidth = 3
                renderer.lineDashPattern = [4, 6]
                renderer.lineJoin = .round
                renderer.lineCap = .round
                return renderer
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 4
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: UserLocationAnnotationView.reuseIdentifier) as? UserLocationAnnotationView
                ?? UserLocationAnnotationView(annotation: annotation, reuseIdentifier: UserLocationAnnotationView.reuseIdentifier)
            view.annotation = annotation
            view.setHeading(userHeading)
            return view
        }

        if let marker = annotation as? DistanceMarkerAnnotation {
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: DistanceMarkerAnnotationView.reuseIdentifier) as? DistanceMarkerAnnotationView
                ?? DistanceMarkerAnnotationView(annotation: marker, reuseIdentifier: DistanceMarkerAnnotationView.reuseIdentifier)
            view.annotation = marker
            return view
        }

        if let marker = annotation as? MeasurementPointAnnotation {
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: MeasurementPointAnnotationView.reuseIdentifier) as? MeasurementPointAnnotationView
                ?? MeasurementPointAnnotationView(annotation: marker, reuseIdentifier: MeasurementPointAnnotationView.reuseIdentifier)
            view.annotation = marker
            return view
        }

        return nil
    }

    func updateUserHeading(on mapView: MKMapView) {
        guard let view = mapView.view(for: mapView.userLocation) as? UserLocationAnnotationView else { return }
        view.setHeading(userHeading)
    }
}

final class DistanceMarkerAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let kmValue: Int
    var title: String? { "\(kmValue)" }

    init(coordinate: CLLocationCoordinate2D, kmValue: Int) {
        self.coordinate = coordinate
        self.kmValue = kmValue
        super.init()
    }
}

final class MeasurementPointAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}

final class UserLocationAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "UserLocationAnnotationView"
    private let dotView = UIView()
    private let arrowLayer = CAShapeLayer()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let dotSize: CGFloat = 18
        dotView.frame = CGRect(
            x: bounds.midX - dotSize / 2,
            y: bounds.midY - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        updateArrowPath()
    }

    func setHeading(_ heading: CLHeading?) {
        guard let heading else {
            arrowLayer.isHidden = true
            return
        }

        let headingValue: CLLocationDirection
        if heading.trueHeading >= 0 {
            headingValue = heading.trueHeading
        } else {
            headingValue = heading.magneticHeading
        }

        arrowLayer.isHidden = false
        let angle = CGFloat(headingValue * .pi / 180)
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        arrowLayer.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        CATransaction.commit()
    }

    private func configureView() {
        frame = CGRect(x: 0, y: 0, width: 42, height: 42)
        backgroundColor = .clear
        centerOffset = .zero

        dotView.backgroundColor = UIColor.systemBlue
        dotView.layer.cornerRadius = 9
        dotView.layer.borderWidth = 2
        dotView.layer.borderColor = UIColor.white.cgColor
        addSubview(dotView)

        arrowLayer.fillColor = UIColor.systemBlue.cgColor
        arrowLayer.bounds = bounds
        arrowLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        layer.addSublayer(arrowLayer)
        updateArrowPath()
        arrowLayer.isHidden = true
    }

    private func updateArrowPath() {
        let tip = CGPoint(x: bounds.midX, y: 2)
        let left = CGPoint(x: bounds.midX - 8, y: 15)
        let right = CGPoint(x: bounds.midX + 8, y: 15)
        let path = UIBezierPath()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.close()
        arrowLayer.path = path.cgPath
        arrowLayer.bounds = bounds
        arrowLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}

final class MeasurementPointAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "MeasurementPointAnnotationView"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    private func configureView() {
        frame = CGRect(x: 0, y: 0, width: 12, height: 12)
        backgroundColor = UIColor.systemOrange
        layer.cornerRadius = 6
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.cgColor
        canShowCallout = false
    }
}

final class DistanceMarkerAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "DistanceMarkerAnnotationView"
    private let label = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override var annotation: MKAnnotation? {
        didSet {
            if let marker = annotation as? DistanceMarkerAnnotation {
                label.text = "\(marker.kmValue)"
            }
        }
    }

    private func configureView() {
        frame = CGRect(x: 0, y: 0, width: 28, height: 28)
        backgroundColor = UIColor.white.withAlphaComponent(0.9)
        layer.cornerRadius = 14
        layer.borderWidth = 2
        layer.borderColor = UIColor.systemBlue.cgColor
        centerOffset = .zero

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor.systemBlue
        label.textAlignment = .center
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
