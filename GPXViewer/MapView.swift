import MapKit
import SwiftUI
import UIKit

struct MapView: UIViewRepresentable {
    let track: GPXTrack?
    let provider: BaseMapProvider
    let offlineMode: Bool
    let followUser: Bool
    let showsUserLocation: Bool
    let onUserInteraction: () -> Void

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
        mapView.showsUserLocation = showsUserLocation

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.userDidInteract(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.userDidInteract(_:)))
        pinchGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(pinchGesture)

        updateTileOverlay(on: mapView, coordinator: context.coordinator)
        updatePolyline(on: mapView, coordinator: context.coordinator)
        updateTracking(on: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.showsUserLocation = showsUserLocation
        updateTileOverlay(on: mapView, coordinator: context.coordinator)
        updatePolyline(on: mapView, coordinator: context.coordinator)
        updateTracking(on: mapView)
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
        mapView.addOverlay(polyline, level: .aboveLabels)

        if !track.bounds.isNull {
            let padding = UIEdgeInsets(top: 120, left: 40, bottom: 180, right: 40)
            mapView.setVisibleMapRect(track.bounds, edgePadding: padding, animated: true)
        }
    }

    private func updateTracking(on mapView: MKMapView) {
        let mode: MKUserTrackingMode = followUser ? .followWithHeading : .none
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

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if userInteracting {
            userInteracting = false
            parent.onUserInteraction()
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let tileOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: tileOverlay)
        }

        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 4
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        return MKOverlayRenderer(overlay: overlay)
    }
}
