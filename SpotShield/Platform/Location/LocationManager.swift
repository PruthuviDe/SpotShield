//
//  LocationManager.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import Combine
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationError: String?

    private let manager = CLLocationManager()
    private var isTracking = false

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocationAccess() {
        isTracking = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func stopUpdatingLocation() {
        isTracking = false
        manager.stopUpdatingLocation()
    }

    func statusMessage(for zones: [ParkingZone]) -> String {
        switch authorizationStatus {
        case .notDetermined:
            return "Allow location to see nearby zones."
        case .denied, .restricted:
            return "Location is off. You can choose a zone manually."
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            return "Location is unavailable. You can choose a zone manually."
        }

        guard let location else {
            return locationError ?? "Finding your location…"
        }

        let zoneDistances = zones.map { zone in
            let zoneLocation = CLLocation(
                latitude: zone.latitude,
                longitude: zone.longitude
            )
            return (
                zone: zone,
                meters: location.distance(from: zoneLocation)
            )
        }

        guard let closestZone = zoneDistances.min(by: {
            $0.meters < $1.meters
        }) else {
            return "No parking zones are available."
        }

        let containingZones = zoneDistances.filter {
            $0.meters <= $0.zone.radiusMeters
        }

        if containingZones.count > 1 {
            return "You appear to be inside multiple parking zones. "
                + "Select the correct zone to continue."
        }

        if let zone = containingZones.first?.zone {
            return "You appear to be inside \(zone.name). Select it to continue."
        }

        return "Closest zone: \(closestZone.zone.name), "
            + "about \(Int(closestZone.meters.rounded())) m away."
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if isTracking {
                manager.startUpdatingLocation()
            }
        case .denied, .restricted:
            location = nil
            manager.stopUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        location = locations.last
        locationError = nil
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        locationError = "Location unavailable. You can choose a zone manually."
    }
}
