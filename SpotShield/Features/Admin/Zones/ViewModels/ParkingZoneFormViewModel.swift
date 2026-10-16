//
//  ParkingZoneFormViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import Foundation
import Observation

@MainActor
@Observable
final class ParkingZoneFormViewModel {
    var name = ""
    var hourlyRateLKR = ""
    var latitude = ""
    var longitude = ""
    var radiusMeters = "100"

    var openingHour = 8
    var closingHour = 18
    var maximumStayMinutes = 120

    var isSaving = false
    var errorMessage = ""

    private let repository = ParkingZoneRepository()
    private let newZoneId = UUID().uuidString
    private var savedZone: ParkingZone?

    var isEditing: Bool {
        savedZone != nil
    }

    init(zone: ParkingZone? = nil) {
        savedZone = zone

        if let zone {
            name = zone.name
            hourlyRateLKR = String(zone.hourlyRateLKR)
            latitude = String(zone.latitude)
            longitude = String(zone.longitude)
            radiusMeters = String(zone.radiusMeters)
            openingHour = zone.openingHour
            closingHour = zone.closingHour
            maximumStayMinutes = zone.maximumStayMinutes
        }
    }

    func saveZone() async -> Bool {
        guard !isSaving else { return false }

        errorMessage = ""

        let cleanName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanName.isEmpty else {
            errorMessage = "Please enter a zone name."
            return false
        }

        guard let price = Int(
            hourlyRateLKR.trimmingCharacters(in: .whitespacesAndNewlines)
        ), price > 0 else {
            errorMessage = "Enter an hourly price greater than zero, using whole rupees."
            return false
        }

        guard let latitudeNumber = Double(
            latitude.trimmingCharacters(in: .whitespacesAndNewlines)
        ), latitudeNumber >= -90, latitudeNumber <= 90 else {
            errorMessage = "Enter a latitude between -90 and 90."
            return false
        }

        guard let longitudeNumber = Double(
            longitude.trimmingCharacters(in: .whitespacesAndNewlines)
        ), longitudeNumber >= -180, longitudeNumber <= 180 else {
            errorMessage = "Enter a longitude between -180 and 180."
            return false
        }

        guard let radiusNumber = Double(
            radiusMeters.trimmingCharacters(in: .whitespacesAndNewlines)
        ), radiusNumber > 0, radiusNumber <= 1000 else {
            errorMessage = "Enter a radius greater than zero and no more than 1,000 metres."
            return false
        }

        guard openingHour >= 0, openingHour <= 23 else {
            errorMessage = "Choose an opening hour between 0 and 23."
            return false
        }

        guard closingHour > openingHour, closingHour <= 24 else {
            errorMessage = "Choose a closing hour after opening, up to 24."
            return false
        }

        let openingMinutes = (closingHour - openingHour) * 60

        guard maximumStayMinutes > 0,
              maximumStayMinutes <= openingMinutes else {
            errorMessage = "Enter a parking limit between 1 and \(openingMinutes) minutes."
            return false
        }

        let zone = ParkingZone(
            id: savedZone?.id ?? newZoneId,
            name: cleanName,
            hourlyRateLKR: price,
            latitude: latitudeNumber,
            longitude: longitudeNumber,
            radiusMeters: radiusNumber,
            openingHour: openingHour,
            closingHour: closingHour,
            maximumStayMinutes: maximumStayMinutes,
            timeZoneId: savedZone?.timeZoneId ?? "Asia/Colombo",
            isPublished: savedZone?.isPublished ?? false,
            isActive: savedZone?.isActive ?? false,
            policyVersion: savedZone?.policyVersion ?? 1,
            wardenAssignmentId: savedZone?.wardenAssignmentId
        )

        isSaving = true

        defer {
            isSaving = false
        }

        do {
            if isEditing {
                savedZone = try await repository.updateZone(zone: zone)
            } else {
                savedZone = try await repository.createZone(zone: zone)
            }

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
