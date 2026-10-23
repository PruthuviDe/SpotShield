//
//  LocationManager.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationError: String?
    @Published private(set) var arrivalAlertsMessage = ""
    @Published private(set) var isRequestingArrivalAlerts = false
    @Published private(set) var requiresAlwaysLocationSettings = false

    private static let monitorName = "SpotShieldParkingZones"
    private static let monitoredZonesKey = "SpotShield.MonitoredParkingZones"
    private static let monitoredUserKey = "SpotShield.MonitoredParkingZonesUser"
    private static let optedInUserKey = "SpotShield.ArrivalAlertsUser"
    private static let zoneIdentifierPrefix = "spotshield-zone-"
    private static let maximumMonitoredZones = 20

    private let manager = CLLocationManager()
    private var isTracking = false
    private var signedInUserId: String?
    private var monitor: CLMonitor?
    private var monitorInitializationTask: Task<CLMonitor, Never>?
    private var serviceSession: CLServiceSession?
    private var monitorTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var eventStreamID: UUID?
    private var diagnosticTask: Task<Void, Never>?
    private var monitorVersion = UUID()
    private var monitoredZones: [MonitoredParkingZone] = []

    private override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
        monitoredZones = Self.savedMonitoredZones()
    }

    var hasArrivalAlertsOptIn: Bool {
        Self.savedOptedInUserId() == signedInUserId && signedInUserId != nil
    }

    var shouldOpenSettingsForArrivalAlerts: Bool {
        manager.authorizationStatus == .denied
            || manager.authorizationStatus == .restricted
            || requiresAlwaysLocationSettings
            || NotificationManager.shared.isZoneArrivalNotificationUnavailable
    }

    func updateSignedInUser(_ userId: String?) {
        guard signedInUserId != userId else {
            resumeArrivalMonitoringIfAllowed()
            return
        }

        let previousUserId = signedInUserId
        signedInUserId = userId

        guard let userId else {
            if previousUserId != nil {
                disableArrivalAlerts(clearSavedZones: true)
            }
            return
        }

        if Self.savedOptedInUserId() == userId,
           Self.savedMonitoredUserId() == userId {
            monitoredZones = Self.savedMonitoredZones()
            resumeArrivalMonitoringIfAllowed()
            return
        }

        if previousUserId != nil || Self.savedOptedInUserId() != nil {
            disableArrivalAlerts(clearSavedZones: true)
        }
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

    func setArrivalAlertsEnabled(for zones: [ParkingZone], userId: String) async {
        guard signedInUserId == userId else { return }

        if Self.savedOptedInUserId() == userId {
            disableArrivalAlerts(clearSavedZones: true)
            await NotificationManager.shared.cancelZoneArrivalNotifications(userId: userId)
            return
        }

        let activeZones = eligibleZones(from: zones, userId: userId)
        guard !activeZones.isEmpty else {
            arrivalAlertsMessage = "There are no active parking zones to monitor."
            return
        }

        isRequestingArrivalAlerts = true
        defer { isRequestingArrivalAlerts = false }

        guard await NotificationManager.shared.requestZoneArrivalPermission() else {
            arrivalAlertsMessage = "Allow notifications in Settings to receive arrival alerts."
            return
        }

        guard signedInUserId == userId else { return }

        monitoredZones = activeZones
        UserDefaults.standard.set(userId, forKey: Self.optedInUserKey)
        UserDefaults.standard.set(userId, forKey: Self.monitoredUserKey)
        saveMonitoredZones(activeZones)
        arrivalAlertsMessage = "Allow Always location access to receive alerts when you arrive."

        serviceSession = CLServiceSession(authorization: .always)
        requiresAlwaysLocationSettings = false
        startAuthorizationDiagnostics(for: serviceSession, userId: userId)

        if manager.authorizationStatus == .authorizedAlways {
            beginMonitoring(activeZones)
        }
    }

    func updateMonitoredZones(_ zones: [ParkingZone], userId: String) {
        guard signedInUserId == userId,
              Self.savedOptedInUserId() == userId else {
            return
        }

        let activeZones = eligibleZones(from: zones, userId: userId)
        guard !activeZones.isEmpty else {
            disableArrivalAlerts(clearSavedZones: true)
            arrivalAlertsMessage = "There are no active parking zones to monitor."
            return
        }

        let previousZones = monitoredZones
        monitoredZones = activeZones
        UserDefaults.standard.set(userId, forKey: Self.monitoredUserKey)
        saveMonitoredZones(activeZones)

        if manager.authorizationStatus == .authorizedAlways {
            beginMonitoring(activeZones, previousZones: previousZones)
        }
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
            if manager.authorizationStatus == .authorizedAlways {
                requiresAlwaysLocationSettings = false
            }
            resumeArrivalMonitoringIfAllowed()
        case .denied, .restricted:
            location = nil
            manager.stopUpdatingLocation()
            if Self.savedOptedInUserId() == signedInUserId {
                arrivalAlertsMessage = "Always location access is needed for arrival alerts. Check Settings."
                requiresAlwaysLocationSettings = true
            }
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

    private func resumeArrivalMonitoringIfAllowed() {
        guard let userId = signedInUserId,
              Self.savedOptedInUserId() == userId,
              Self.savedMonitoredUserId() == userId,
              manager.authorizationStatus == .authorizedAlways,
              !monitoredZones.isEmpty else {
            return
        }

        if serviceSession == nil {
            serviceSession = CLServiceSession(authorization: .always)
        }

        beginMonitoring(monitoredZones)
    }

    private func beginMonitoring(
        _ zones: [MonitoredParkingZone],
        previousZones: [MonitoredParkingZone]? = nil
    ) {
        monitorVersion = UUID()
        let version = monitorVersion
        monitorTask?.cancel()
        isRequestingArrivalAlerts = true

        monitorTask = Task { [weak self] in
            guard let self else { return }
            let activeMonitor = await self.parkingZoneMonitor()

            guard !Task.isCancelled,
                  self.monitorVersion == version,
                  let userId = self.signedInUserId,
                  Self.savedOptedInUserId() == userId,
                  self.manager.authorizationStatus == .authorizedAlways else {
                return
            }

            self.monitor = activeMonitor
            self.startEventStream(for: activeMonitor)

            let existingIdentifiers = await activeMonitor.identifiers
            let desiredIdentifiers = Set(zones.map(\.conditionIdentifier))
            let previousByIdentifier = Dictionary(
                uniqueKeysWithValues: (previousZones ?? self.monitoredZones).map {
                    ($0.conditionIdentifier, $0)
                }
            )

            for identifier in existingIdentifiers where identifier.hasPrefix(Self.zoneIdentifierPrefix) {
                guard desiredIdentifiers.contains(identifier),
                      let nextZone = zones.first(where: {
                          $0.conditionIdentifier == identifier
                      }),
                      previousByIdentifier[identifier] == nextZone else {
                    await activeMonitor.remove(identifier)
                    continue
                }
            }

            let remainingIdentifiers = await activeMonitor.identifiers

            for zone in zones where !remainingIdentifiers.contains(zone.conditionIdentifier) {
                let condition = CLMonitor.CircularGeographicCondition(
                    center: CLLocationCoordinate2D(
                        latitude: zone.latitude,
                        longitude: zone.longitude
                    ),
                    radius: zone.radiusMeters
                )

                await activeMonitor.add(
                    condition,
                    identifier: zone.conditionIdentifier,
                    assuming: .unsatisfied
                )
            }

            guard self.monitorVersion == version else { return }
            self.arrivalAlertsMessage = "Arrival alerts are on for \(zones.count) active parking zone\(zones.count == 1 ? "" : "s")."
            self.isRequestingArrivalAlerts = false
        }
    }

    private func startEventStream(for monitor: CLMonitor) {
        guard eventTask == nil else { return }
        let streamID = UUID()
        eventStreamID = streamID

        eventTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.eventStreamID == streamID {
                    self.eventTask = nil
                    self.eventStreamID = nil
                }
            }

            do {
                for try await event in await monitor.events {
                    guard !Task.isCancelled,
                          self.eventStreamID == streamID else {
                        break
                    }

                    guard event.state == .satisfied,
                          let zone = self.monitoredZones.first(where: {
                              $0.conditionIdentifier == event.identifier
                          }),
                          zone.userId == self.signedInUserId else {
                        continue
                    }

                    await NotificationManager.shared.scheduleZoneArrivalNotification(
                        zoneId: zone.id,
                        zoneName: zone.name,
                        userId: zone.userId
                    )
                }
            } catch {
                guard !Task.isCancelled,
                      self.eventStreamID == streamID else { return }
                self.arrivalAlertsMessage = "Arrival alerts could not start. Try enabling them again."
                self.isRequestingArrivalAlerts = false
            }
        }
    }

    private func startAuthorizationDiagnostics(
        for session: CLServiceSession?,
        userId: String
    ) {
        guard let session else { return }

        diagnosticTask?.cancel()
        diagnosticTask = Task { [weak self] in
            do {
                for try await diagnostic in session.diagnostics {
                    guard !Task.isCancelled,
                          let self,
                          self.signedInUserId == userId else {
                        break
                    }

                    if !diagnostic.authorizationRequestInProgress {
                        if diagnostic.authorizationDenied {
                            self.arrivalAlertsMessage = "Always location access is needed for arrival alerts. Check Settings."
                            self.requiresAlwaysLocationSettings = true
                        }
                        break
                    }
                }
            } catch {
                guard let self, self.signedInUserId == userId else { return }
                self.arrivalAlertsMessage = "Location access could not be updated. Check Settings."
            }
        }
    }

    private func disableArrivalAlerts(clearSavedZones: Bool) {
        monitorVersion = UUID()
        let version = monitorVersion
        monitorTask?.cancel()
        eventTask?.cancel()
        diagnosticTask?.cancel()
        eventStreamID = nil
        serviceSession = nil
        monitorTask = nil
        eventTask = nil
        diagnosticTask = nil
        isRequestingArrivalAlerts = false
        arrivalAlertsMessage = "Arrival alerts are off."
        requiresAlwaysLocationSettings = false
        guard clearSavedZones else { return }

        UserDefaults.standard.removeObject(forKey: Self.optedInUserKey)
        UserDefaults.standard.removeObject(forKey: Self.monitoredUserKey)
        UserDefaults.standard.removeObject(forKey: Self.monitoredZonesKey)
        monitoredZones = []

        Task { [weak self] in
            guard let self else { return }
            let activeMonitor = await self.parkingZoneMonitor()
            guard self.monitorVersion == version else { return }
            let identifiers = await activeMonitor.identifiers
            for identifier in identifiers where identifier.hasPrefix(Self.zoneIdentifierPrefix) {
                guard self.monitorVersion == version else { return }
                await activeMonitor.remove(identifier)
            }
        }
    }

    private func parkingZoneMonitor() async -> CLMonitor {
        if let monitor {
            return monitor
        }

        if let monitorInitializationTask {
            let activeMonitor = await monitorInitializationTask.value
            monitor = activeMonitor
            self.monitorInitializationTask = nil
            return activeMonitor
        }

        let initializationTask = Task {
            await CLMonitor(Self.monitorName)
        }
        monitorInitializationTask = initializationTask

        let activeMonitor = await initializationTask.value
        monitor = activeMonitor
        monitorInitializationTask = nil
        return activeMonitor
    }

    private func eligibleZones(from zones: [ParkingZone], userId: String) -> [MonitoredParkingZone] {
        let activeZones = zones.filter {
            $0.isPublished
                && $0.isActive
                && CLLocationCoordinate2DIsValid(
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                )
                && $0.radiusMeters > 0
        }

        return activeZones
            .sorted { first, second in
                if let location {
                    let firstLocation = CLLocation(latitude: first.latitude, longitude: first.longitude)
                    let secondLocation = CLLocation(latitude: second.latitude, longitude: second.longitude)
                    return location.distance(from: firstLocation) < location.distance(from: secondLocation)
                }
                return first.name < second.name
            }
            .prefix(Self.maximumMonitoredZones)
            .map { zone in
                MonitoredParkingZone(
                    id: zone.id,
                    name: zone.name,
                    userId: userId,
                    latitude: zone.latitude,
                    longitude: zone.longitude,
                    radiusMeters: zone.radiusMeters
                )
            }
    }

    private func saveMonitoredZones(_ zones: [MonitoredParkingZone]) {
        guard let data = try? JSONEncoder().encode(zones) else { return }
        UserDefaults.standard.set(data, forKey: Self.monitoredZonesKey)
    }

    private static func savedMonitoredZones() -> [MonitoredParkingZone] {
        guard let data = UserDefaults.standard.data(forKey: monitoredZonesKey),
              let zones = try? JSONDecoder().decode([MonitoredParkingZone].self, from: data) else {
            return []
        }
        return zones
    }

    private static func savedMonitoredUserId() -> String? {
        UserDefaults.standard.string(forKey: monitoredUserKey)
    }

    private static func savedOptedInUserId() -> String? {
        UserDefaults.standard.string(forKey: optedInUserKey)
    }
}

private struct MonitoredParkingZone: Codable, Equatable {
    let id: String
    let name: String
    let userId: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double

    var conditionIdentifier: String {
        "spotshield-zone-\(id)"
    }
}
