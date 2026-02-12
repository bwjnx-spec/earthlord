//
//  TerritoryMapView.swift
//  earthlord
//
//  领地详情页全屏地图底图（UIViewRepresentable 包装 MKMapView）
//

import SwiftUI
import MapKit

struct TerritoryMapView: UIViewRepresentable {

    let territory: Territory
    let buildings: [PlayerBuilding]
    let templates: [BuildingTemplate]
    var buildingsVersion: Int

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.delegate = context.coordinator

        // Apply apocalypse filter
        applyApocalypseFilter(to: mapView)

        // Set initial region to territory bounds
        let region = regionForTerritory()
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard context.coordinator.lastBuildingsVersion != buildingsVersion else { return }
        context.coordinator.lastBuildingsVersion = buildingsVersion

        // Remove old overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        let buildingAnnotations = mapView.annotations.compactMap { $0 as? BuildingAnnotation }
        mapView.removeAnnotations(buildingAnnotations)

        // Draw territory polygon
        let coordinates = territory.toCoordinates()
        guard coordinates.count >= 3 else { return }
        var coords = coordinates
        let polygon = MKPolygon(coordinates: &coords, count: coords.count)
        polygon.title = "territory"
        mapView.addOverlay(polygon, level: .aboveRoads)

        // Add building annotations
        for building in buildings {
            let annotation = BuildingAnnotation(building: building, template: templateFor(building))
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Helpers

    private func regionForTerritory() -> MKCoordinateRegion {
        let coordinates = territory.toCoordinates()
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 30.0, longitude: 104.0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLon = (lons.min()! + lons.max()!) / 2
        let spanLat = (lats.max()! - lats.min()!) * 1.5
        let spanLon = (lons.max()! - lons.min()!) * 1.5
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(spanLat, 0.003), longitudeDelta: max(spanLon, 0.003))
        )
    }

    private func templateFor(_ building: PlayerBuilding) -> BuildingTemplate? {
        templates.first { $0.templateId == building.templateId }
    }

    private func applyApocalypseFilter(to mapView: MKMapView) {
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 0.15)
        overlayView.isUserInteractionEnabled = false
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: mapView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: mapView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: mapView.trailingAnchor)
        ])
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var lastBuildingsVersion: Int = -1

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            guard let buildingAnnotation = annotation as? BuildingAnnotation else { return nil }

            let identifier = "BuildingAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = annotation
            }

            // Create circular icon
            let size: CGFloat = 32
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            let isConstructing = buildingAnnotation.building.status == .constructing
            let bgColor = isConstructing ? UIColor.orange : UIColor.systemGreen

            view?.image = renderer.image { ctx in
                bgColor.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))

                let icon = UIImage(systemName: buildingAnnotation.iconName ?? "building.2")?
                    .withTintColor(.white, renderingMode: .alwaysOriginal)
                    .withConfiguration(UIImage.SymbolConfiguration(pointSize: 14))
                let iconSize = icon?.size ?? .zero
                let iconOrigin = CGPoint(
                    x: (size - iconSize.width) / 2,
                    y: (size - iconSize.height) / 2
                )
                icon?.draw(at: iconOrigin)
            }

            view?.centerOffset = CGPoint(x: 0, y: -size / 2)
            return view
        }
    }
}

// MARK: - BuildingAnnotation

class BuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let iconName: String?

    var coordinate: CLLocationCoordinate2D {
        building.coordinate
    }

    var title: String? {
        building.buildingName
    }

    var subtitle: String? {
        if building.status == .constructing {
            return "建造中 \(building.formattedRemainingTime)"
        }
        return "Lv.\(building.level) \(building.status.displayName)"
    }

    init(building: PlayerBuilding, template: BuildingTemplate?) {
        self.building = building
        self.iconName = template?.icon
        super.init()
    }
}
