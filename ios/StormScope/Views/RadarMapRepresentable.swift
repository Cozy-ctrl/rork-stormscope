import SwiftUI
import MapKit

/// A tile overlay that also carries the radar frame suffix so stale frames
/// can be identified and swapped without touching warning polygons.
final class RadarTileOverlay: MKTileOverlay {
    let frameSuffix: String

    init(frameSuffix: String) {
        self.frameSuffix = frameSuffix
        // Iowa Environmental Mesonet mirrors NWS NEXRAD base reflectivity as
        // free XYZ tiles; time-shifted layers cover the last 50 minutes.
        let template = "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913\(frameSuffix)/{z}/{x}/{y}.png"
        super.init(urlTemplate: template)
        canReplaceMapContent = false
        tileSize = CGSize(width: 256, height: 256)
    }
}

/// Single-site NEXRAD Storm Relative Radial Velocity (N0S) tiles from the
/// Iowa Environmental Mesonet RIDGE archive. Green = motion toward the radar,
/// red = motion away; adjacent green/red couplets indicate rotation.
final class VelocityTileOverlay: MKTileOverlay {
    let siteID: String

    init(siteID: String) {
        self.siteID = siteID
        let template = "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/ridge::\(siteID)-N0S-0/{z}/{x}/{y}.png"
        super.init(urlTemplate: template)
        canReplaceMapContent = false
        tileSize = CGSize(width: 256, height: 256)
    }
}

/// GOES infrared cloud-top tiles from the Iowa Environmental Mesonet.
/// East vs. West satellite is chosen by the map center's longitude so the
/// Rockies and westward get the better viewing angle.
final class SatelliteTileOverlay: MKTileOverlay {
    init(centerLongitude: Double) {
        let layer = centerLongitude < -105 ? "goes_west_conus_ch13" : "goes_east_conus_ch13"
        let template = "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/\(layer)/{z}/{x}/{y}.png"
        super.init(urlTemplate: template)
        canReplaceMapContent = false
        tileSize = CGSize(width: 256, height: 256)
    }
}

/// MKPolygon subclass that remembers which NWS alert it belongs to so taps
/// can surface the warning text. Marked nonisolated because it is a pure
/// data carrier for MapKit with no UI work — it's created on the main actor
/// but read from MKMapViewDelegate callbacks.
nonisolated final class WarningPolygon: MKPolygon {
    var alertID: String?
    var isTornado: Bool = false
    var severityRank: Int = 0
}

/// MapKit-backed radar view: animated NEXRAD tiles + active watch/warning
/// polygons. SwiftUI `Map` can't render tile overlays, so this wraps MKMapView.
struct RadarMapRepresentable: UIViewRepresentable {
    let center: CLLocationCoordinate2D
    let frameSuffix: String
    let layerMode: RadarLayerMode
    /// Nearest NEXRAD site identifier (e.g. "TLX") for single-site velocity tiles.
    let velocitySiteID: String?
    let alerts: [NWSAlertFeature]
    let onSelectAlert: (NWSAlertFeature) -> Void
    /// Called when tile fetching starts for a new frame (true) and when the
    /// stale overlays are cleaned up after a settling delay (false).
    var onTilesLoading: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.overrideUserInterfaceStyle = .dark
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 300_000,
            longitudinalMeters: 300_000
        )
        mapView.setRegion(region, animated: false)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncSatellite(on: mapView, mode: layerMode, centerLongitude: center.longitude)
        context.coordinator.syncVelocity(on: mapView, mode: layerMode, siteID: velocitySiteID)
        context.coordinator.syncRadarFrame(on: mapView, suffix: frameSuffix, mode: layerMode)
        context.coordinator.syncPolygons(on: mapView, alerts: alerts)
        context.coordinator.recenterIfNeeded(on: mapView, center: center)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RadarMapRepresentable
        private var currentSuffix: String?
        private var currentAlertIDs: Set<String> = []
        private var lastCenterKey: String?
        /// Pending delayed removal of the previous radar tile overlay so the
        /// new frame has time to fetch tiles before the old one disappears.
        private var pendingStaleRemoval: DispatchWorkItem?

        init(_ parent: RadarMapRepresentable) {
            self.parent = parent
        }

        /// Adds or removes the GOES layer beneath everything else. The
        /// overlay is rebuilt when the map center crosses the East/West
        /// satellite boundary.
        func syncSatellite(on mapView: MKMapView, mode: RadarLayerMode, centerLongitude: Double) {
            let existing = mapView.overlays.compactMap { $0 as? SatelliteTileOverlay }
            if mode.showsSatellite {
                if existing.isEmpty {
                    mapView.insertOverlay(SatelliteTileOverlay(centerLongitude: centerLongitude), at: 0)
                }
            } else if !existing.isEmpty {
                mapView.removeOverlays(existing)
            }
        }

        /// Adds or removes the single-site velocity layer. The overlay is
        /// rebuilt when the nearest radar site changes.
        func syncVelocity(on mapView: MKMapView, mode: RadarLayerMode, siteID: String?) {
            let existing = mapView.overlays.compactMap { $0 as? VelocityTileOverlay }
            if mode.showsVelocity, let siteID {
                if let current = existing.first, current.siteID == siteID { return }
                if !existing.isEmpty { mapView.removeOverlays(existing) }
                mapView.addOverlay(VelocityTileOverlay(siteID: siteID), level: .aboveRoads)
            } else if !existing.isEmpty {
                mapView.removeOverlays(existing)
            }
        }

        func syncRadarFrame(on mapView: MKMapView, suffix: String, mode: RadarLayerMode) {
            guard mode.showsRadar else {
                // Satellite-only: clear any radar tiles and reset frame state
                // so re-enabling radar re-adds the current frame.
                pendingStaleRemoval?.cancel()
                let radarOverlays = mapView.overlays.compactMap { $0 as? RadarTileOverlay }
                if !radarOverlays.isEmpty {
                    mapView.removeOverlays(radarOverlays)
                }
                currentSuffix = nil
                return
            }
            guard suffix != currentSuffix else { return }
            currentSuffix = suffix

            // Cancel any pending cleanup from the previous frame transition.
            pendingStaleRemoval?.cancel()

            // Snapshot which overlays are now stale BEFORE adding the new one.
            let stale = mapView.overlays.compactMap { $0 as? RadarTileOverlay }

            // Add the new overlay on top — its tiles load asynchronously while
            // the old overlay's tiles remain visible underneath.
            mapView.addOverlay(RadarTileOverlay(frameSuffix: suffix), level: .aboveRoads)

            parent.onTilesLoading?(true)

            // Remove stale overlays after a settling delay so the new tiles
            // have time to arrive from the network.
            let workItem = DispatchWorkItem { [weak mapView, weak self] in
                mapView?.removeOverlays(stale)
                self?.parent.onTilesLoading?(false)
            }
            pendingStaleRemoval = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.4, execute: workItem)
        }

        func syncPolygons(on mapView: MKMapView, alerts: [NWSAlertFeature]) {
            let ids = Set(alerts.map { $0.id })
            guard ids != currentAlertIDs else { return }
            currentAlertIDs = ids

            let stale = mapView.overlays.compactMap { $0 as? WarningPolygon }
            mapView.removeOverlays(stale)

            for alert in alerts {
                guard let geometry = alert.geometry else { continue }
                for ring in geometry.outerRings {
                    let coordinates = ring.compactMap { pair -> CLLocationCoordinate2D? in
                        guard pair.count >= 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                    }
                    guard coordinates.count >= 3 else { continue }
                    let polygon = WarningPolygon(coordinates: coordinates, count: coordinates.count)
                    polygon.alertID = alert.id
                    polygon.isTornado = alert.isTornadoRelated
                    polygon.severityRank = alert.severityRank
                    mapView.addOverlay(polygon, level: .aboveLabels)
                }
            }
        }

        func recenterIfNeeded(on mapView: MKMapView, center: CLLocationCoordinate2D) {
            let key = String(format: "%.2f,%.2f", center.latitude, center.longitude)
            guard key != lastCenterKey else { return }
            let isFirst = lastCenterKey == nil
            lastCenterKey = key
            let region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 300_000,
                longitudinalMeters: 300_000
            )
            mapView.setRegion(region, animated: !isFirst)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)

            let hits = mapView.overlays
                .compactMap { $0 as? WarningPolygon }
                .filter { polygon in
                    guard let renderer = mapView.renderer(for: polygon) as? MKPolygonRenderer else { return false }
                    let rendererPoint = renderer.point(for: mapPoint)
                    return renderer.path?.contains(rendererPoint) ?? false
                }
            // Prefer the most severe warning when polygons overlap.
            guard let best = hits.max(by: { $0.severityRank < $1.severityRank }),
                  let alert = parent.alerts.first(where: { $0.id == best.alertID }) else { return }
            parent.onSelectAlert(alert)
        }

        // MARK: - MKMapViewDelegate

        nonisolated func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let satellite = overlay as? SatelliteTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: satellite)
                renderer.alpha = 0.82
                return renderer
            }
            if let velocity = overlay as? VelocityTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: velocity)
                renderer.alpha = 0.78
                return renderer
            }
            if let tile = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tile)
                renderer.alpha = 0.72
                return renderer
            }
            if let polygon = overlay as? WarningPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let color: UIColor = polygon.isTornado
                    ? UIColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 1)
                    : polygon.severityRank >= 3
                        ? UIColor(red: 0.98, green: 0.58, blue: 0.28, alpha: 1)
                        : UIColor(red: 0.93, green: 0.72, blue: 0.35, alpha: 1)
                renderer.strokeColor = color
                renderer.fillColor = color.withAlphaComponent(0.16)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
