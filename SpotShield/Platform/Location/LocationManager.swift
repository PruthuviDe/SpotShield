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

        guard let closestZone = zones.min(by: { firstZone, secondZone in
            let firstLocation = CLLocation(
                latitude: firstZone.latitude,
                longitude: firstZone.longitude
            )
            let secondLocation = CLLocation(
                latitude: secondZone.latitude,
                longitude: secondZone.longitude
            )

            return location.distance(from: firstLocation)
                < location.distance(from: secondLocation)
        }) else {
            return "No parking zones are available."
        }

        let zoneLocation = CLLocation(
            latitude: closestZone.latitude,
            longitude: closestZone.longitude
        )
        let distance = location.distance(from: zoneLocation)

        if distance <= closestZone.radiusMeters {
            return "You appear to be inside \(closestZone.name). Select it to continue."
        }

        return "Closest zone: \(closestZone.name), about \(Int(distance.rounded())) m away."
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
