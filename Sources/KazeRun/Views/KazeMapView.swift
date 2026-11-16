import SwiftUI
import MapKit
import AppKit

/// Google Maps tile overlay with GCJ-02 tile-shift for China region MKMapView.
/// MKMapView in China uses GCJ-02 coordinates internally.
/// Google tiles are WGS-84-based. To align them, we reverse-shift the tile request
/// by converting the tile center from GCJ-02 (MKMapView) back to WGS-84 (Google expects).
final class GoogleTileOverlay: MKTileOverlay {
    private let chinaRegion: Bool

    init(chinaRegion: Bool) {
        self.chinaRegion = chinaRegion
        super.init(urlTemplate: nil)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        var x = path.x
        var y = path.y
        let z = path.z

        if chinaRegion {
            // Shift tile coordinates: MKMapView requests tiles in GCJ-02 space,
            // but Google serves WGS-84 tiles. Convert tile center GCJ-02 -> WGS-84
            // and find the corresponding WGS-84 tile.
            let n = Double(1 << z)
            let tileLon = Double(x) / n * 360.0 - 180.0 + 180.0 / n
            let tileLat = atan(sinh(.pi * (1.0 - 2.0 * Double(y) / n))) * 180.0 / .pi

            let wgs = CoordinateTransform.gcj02ToWgs84(lat: tileLat, lon: tileLon)
            let wgsX = Int(floor((wgs.lon + 180.0) / 360.0 * n))
            let wgsY = Int(floor((1.0 - log(tan(wgs.lat * .pi / 180.0) + 1.0 / cos(wgs.lat * .pi / 180.0)) / .pi) / 2.0 * n))
            x = max(0, min(Int(n) - 1, wgsX))
            y = max(0, min(Int(n) - 1, wgsY))
        }

        let sub = ["mt0", "mt1", "mt2", "mt3"][abs(x + y) % 4]
        let urlStr = "https://\(sub).google.com/vt/lyrs=m&x=\(x)&y=\(y)&z=\(z)"
        return URL(string: urlStr)!
    }
}

/// AMap (AutoNavi / 高德) tile overlay. Already GCJ-02 aligned with MKMapView in China.
final class AMapTileOverlay: MKTileOverlay {
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let sub = ["webrd01", "webrd02", "webrd03", "webrd04"][abs(path.x + path.y) % 4]
        let urlStr = "https://\(sub).is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x=\(path.x)&y=\(path.y)&z=\(path.z)"
        return URL(string: urlStr)!
    }
}

final class HoverCursorAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

final class StartFinishAnnotation: NSObject, MKAnnotation {
    enum PointType {
        case start
        case finish
    }

    let coordinate: CLLocationCoordinate2D
    let type: PointType
    let title: String?

    init(coordinate: CLLocationCoordinate2D, type: PointType, title: String) {
        self.coordinate = coordinate
        self.type = type
        self.title = title
    }
}

struct KazeMapView: NSViewRepresentable {
    let polyline: [[Double]]
    var hoveredCoordinate: CLLocationCoordinate2D? = nil
    let provider: MapProvider
    let calibrateGcj02: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = true
        mapView.showsScale = true
        context.coordinator.updateMap(mapView: mapView, parent: self)
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.updateMap(mapView: mapView, parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: KazeMapView
        private var currentOverlayProvider: MapProvider?
        private var currentTileOverlay: MKTileOverlay?
        private var lastPolylineCount: Int = -1
        private var lastProvider: MapProvider?
        private var hoverCursorAnnotation: HoverCursorAnnotation?

        init(_ parent: KazeMapView) {
            self.parent = parent
        }

        func updateMap(mapView: MKMapView, parent: KazeMapView) {
            self.parent = parent

            guard !parent.polyline.isEmpty else {
                mapView.removeOverlays(mapView.overlays)
                mapView.removeAnnotations(mapView.annotations)
                hoverCursorAnnotation = nil
                return
            }

            let sample = parent.polyline.first ?? [0.0, 0.0]
            let isOverseas = CoordinateTransform.isOutOfChina(lat: sample[0], lon: sample[1])

            let effectiveProvider: MapProvider
            switch parent.provider {
            case .auto:
                effectiveProvider = isOverseas ? .google : .apple
            case .google:
                effectiveProvider = .google
            case .amap:
                effectiveProvider = .amap
            case .apple:
                effectiveProvider = .apple
            }

            // Manage tile overlays - rebuild if provider changed
            if currentOverlayProvider != effectiveProvider {
                if let old = currentTileOverlay {
                    mapView.removeOverlay(old)
                    currentTileOverlay = nil
                }
                currentOverlayProvider = effectiveProvider

                switch effectiveProvider {
                case .google:
                    // Pass chinaRegion flag so Google tiles get GCJ-02 shift correction
                    let googleOverlay = GoogleTileOverlay(chinaRegion: !isOverseas)
                    googleOverlay.canReplaceMapContent = true
                    mapView.addOverlay(googleOverlay, level: .aboveRoads)
                    currentTileOverlay = googleOverlay
                case .amap:
                    let amapOverlay = AMapTileOverlay()
                    amapOverlay.canReplaceMapContent = true
                    mapView.addOverlay(amapOverlay, level: .aboveRoads)
                    currentTileOverlay = amapOverlay
                case .apple, .auto:
                    break
                }
            }

            // Coordinate transformation:
            // MKMapView in China uses GCJ-02 internally. ALL coordinates placed on it
            // (polyline, annotations) must be in GCJ-02 when in mainland China,
            // regardless of which tile overlay is displayed.
            // For overseas tracks, no transform needed (both MKMapView and GPS are WGS-84).
            let polylineChanged = lastPolylineCount != parent.polyline.count || lastProvider != effectiveProvider
            if polylineChanged {
                lastPolylineCount = parent.polyline.count
                lastProvider = effectiveProvider

                let coords: [CLLocationCoordinate2D] = parent.polyline.compactMap { pair in
                    guard pair.count >= 2 else { return nil }
                    let lat = pair[0]
                    let lon = pair[1]
                    if parent.calibrateGcj02 && !isOverseas {
                        let c = CoordinateTransform.wgs84ToGcj02(lat: lat, lon: lon)
                        return CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon)
                    }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }

                guard coords.count > 1 else { return }

                // Update Polyline and Markers
                let polylineOverlays = mapView.overlays.filter { $0 is MKPolyline }
                mapView.removeOverlays(polylineOverlays)
                let nonCursorAnnotations = mapView.annotations.filter { !($0 is HoverCursorAnnotation) }
                mapView.removeAnnotations(nonCursorAnnotations)

                let mkPolyline = MKPolyline(coordinates: coords, count: coords.count)
                mapView.addOverlay(mkPolyline, level: .aboveLabels)

                if let first = coords.first {
                    let startAnno = StartFinishAnnotation(coordinate: first, type: .start, title: "起点")
                    mapView.addAnnotation(startAnno)
                }
                if let last = coords.last {
                    let finishAnno = StartFinishAnnotation(coordinate: last, type: .finish, title: "终点")
                    mapView.addAnnotation(finishAnno)
                }

                // Zoom to fit
                let mapRect = mkPolyline.boundingMapRect
                mapView.setVisibleMapRect(
                    mapRect,
                    edgePadding: NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
                    animated: false
                )
            }

            // Crosshair sync: update hover cursor annotation
            if let rawHover = parent.hoveredCoordinate {
                let hoverCoord: CLLocationCoordinate2D
                if parent.calibrateGcj02 && !isOverseas {
                    let c = CoordinateTransform.wgs84ToGcj02(lat: rawHover.latitude, lon: rawHover.longitude)
                    hoverCoord = CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon)
                } else {
                    hoverCoord = rawHover
                }

                if let existing = hoverCursorAnnotation, mapView.annotations.contains(where: { $0 === existing }) {
                    existing.coordinate = hoverCoord
                } else {
                    let newAnno = HoverCursorAnnotation(coordinate: hoverCoord)
                    hoverCursorAnnotation = newAnno
                    mapView.addAnnotation(newAnno)
                }
            } else {
                if let existing = hoverCursorAnnotation {
                    mapView.removeAnnotation(existing)
                    hoverCursorAnnotation = nil
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor(red: 225.0 / 255.0, green: 75.0 / 255.0, blue: 50.0 / 255.0, alpha: 1.0)
                renderer.lineWidth = 3.5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let hoverAnno = annotation as? HoverCursorAnnotation {
                let identifier = "HoverCursorAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
                    view?.canShowCallout = false
                    view?.displayPriority = .required

                    let dot = NSView(frame: CGRect(x: 1, y: 1, width: 20, height: 20))
                    dot.wantsLayer = true
                    dot.layer?.backgroundColor = NSColor(red: 225.0 / 255.0, green: 75.0 / 255.0, blue: 50.0 / 255.0, alpha: 1.0).cgColor
                    dot.layer?.cornerRadius = 10
                    dot.layer?.borderWidth = 3
                    dot.layer?.borderColor = NSColor.white.cgColor
                    dot.layer?.shadowColor = NSColor.black.cgColor
                    dot.layer?.shadowOpacity = 0.45
                    dot.layer?.shadowOffset = CGSize(width: 0, height: -2)
                    dot.layer?.shadowRadius = 4
                    view?.addSubview(dot)
                }
                view?.annotation = hoverAnno
                return view
            }

            guard let pt = annotation as? StartFinishAnnotation else { return nil }
            let identifier = "StartFinishPin"
            let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            pinView.annotation = pt

            switch pt.type {
            case .start:
                pinView.markerTintColor = NSColor(red: 98.0 / 255.0, green: 125.0 / 255.0, blue: 119.0 / 255.0, alpha: 1.0)
                pinView.glyphText = "S"
            case .finish:
                pinView.markerTintColor = NSColor(red: 225.0 / 255.0, green: 75.0 / 255.0, blue: 50.0 / 255.0, alpha: 1.0)
                pinView.glyphText = "F"
            }
            pinView.displayPriority = .required
            return pinView
        }
    }
}
