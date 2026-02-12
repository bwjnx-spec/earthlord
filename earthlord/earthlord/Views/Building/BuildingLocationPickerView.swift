//
//  BuildingLocationPickerView.swift
//  earthlord
//
//  建造位置选择器（UIViewRepresentable 包装 MKMapView）
//  MKMapView 在中国返回 GCJ-02 坐标，领地坐标也是 GCJ-02，可直接比较
//

import SwiftUI
import MapKit

struct BuildingLocationPickerView: UIViewRepresentable {

    let territory: Territory
    let existingBuildings: [PlayerBuilding]
    let templates: [BuildingTemplate]
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var isLocationValid: Bool

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.delegate = context.coordinator

        // Apply apocalypse filter
        applyApocalypseFilter(to: mapView)

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        // Set initial region
        let region = regionForTerritory()
        mapView.setRegion(region, animated: false)

        // Draw territory polygon
        drawTerritory(on: mapView)

        // Draw existing buildings
        drawExistingBuildings(on: mapView, context: context)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update selected pin
        let existingPins = mapView.annotations.compactMap { $0 as? SelectedLocationAnnotation }
        mapView.removeAnnotations(existingPins)

        if let location = selectedLocation {
            let pin = SelectedLocationAnnotation(coordinate: location)
            mapView.addAnnotation(pin)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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

    private func drawTerritory(on mapView: MKMapView) {
        let coordinates = territory.toCoordinates()
        guard coordinates.count >= 3 else { return }
        var coords = coordinates
        let polygon = MKPolygon(coordinates: &coords, count: coords.count)
        polygon.title = "territory"
        mapView.addOverlay(polygon, level: .aboveRoads)
    }

    private func drawExistingBuildings(on mapView: MKMapView, context: Context) {
        for building in existingBuildings {
            let template = templates.first { $0.templateId == building.templateId }
            let annotation = BuildingAnnotation(building: building, template: template)
            mapView.addAnnotation(annotation)
        }
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
        var parent: BuildingLocationPickerView

        init(_ parent: BuildingLocationPickerView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // Validate: is the point inside the territory polygon?
            let polygon = parent.territory.toCoordinates()
            let territoryManager = TerritoryManager()
            let isValid = territoryManager.isPointInPolygon(point: coordinate, polygon: polygon)

            DispatchQueue.main.async {
                self.parent.selectedLocation = coordinate
                self.parent.isLocationValid = isValid
            }
        }

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

            // Selected location pin
            if let selectedAnnotation = annotation as? SelectedLocationAnnotation {
                let identifier = "SelectedLocation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    view?.annotation = annotation
                }
                view?.markerTintColor = selectedAnnotation.isValid ? .systemGreen : .systemRed
                view?.glyphImage = UIImage(systemName: "building.2.fill")
                view?.animatesWhenAdded = true
                return view
            }

            // Existing building annotations
            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "ExistingBuilding"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = annotation
                }

                let size: CGFloat = 28
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                let isConstructing = buildingAnnotation.building.status == .constructing
                let bgColor = isConstructing ? UIColor.orange : UIColor.systemGreen

                view?.image = renderer.image { ctx in
                    bgColor.withAlphaComponent(0.8).setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                    let icon = UIImage(systemName: buildingAnnotation.iconName ?? "building.2")?
                        .withTintColor(.white, renderingMode: .alwaysOriginal)
                        .withConfiguration(UIImage.SymbolConfiguration(pointSize: 12))
                    let iconSize = icon?.size ?? .zero
                    icon?.draw(at: CGPoint(x: (size - iconSize.width) / 2, y: (size - iconSize.height) / 2))
                }
                view?.centerOffset = CGPoint(x: 0, y: -size / 2)
                return view
            }

            return nil
        }
    }
}

// MARK: - SelectedLocationAnnotation

class SelectedLocationAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var isValid: Bool = true

    var title: String? { "建造位置" }

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}
