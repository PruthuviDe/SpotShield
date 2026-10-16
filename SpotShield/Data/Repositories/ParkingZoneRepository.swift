//
//  ParkingZoneRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import Foundation
import FirebaseFirestore

final class ParkingZoneRepository {
    private let database = Firestore.firestore()

    func getZones() async throws -> [ParkingZone] {
        let result = try await database
            .collection("parkingZones")
            .order(by: "name")
            .getDocuments()

        var zones: [ParkingZone] = []

        for document in result.documents {
            let zone = try readZone(from: document)
            zones.append(zone)
        }

        return zones
    }

    func createZone(zone: ParkingZone) async throws -> ParkingZone {
        guard !zone.id.isEmpty else {
            throw ParkingZoneError.missingId
        }

        var newZone = zone
        newZone.isPublished = false
        newZone.isActive = false
        newZone.policyVersion = 1

        try await database
            .collection("parkingZones")
            .document(newZone.id)
            .setData(zoneData(zone: newZone))

        return newZone
    }

    func updateZone(zone: ParkingZone) async throws -> ParkingZone {
        guard !zone.id.isEmpty else {
            throw ParkingZoneError.missingId
        }

        var updatedZone = zone
        updatedZone.policyVersion += 1

        try await database
            .collection("parkingZones")
            .document(updatedZone.id)
            .updateData(zoneData(zone: updatedZone))

        return updatedZone
    }

    private func zoneData(zone: ParkingZone) -> [String: Any] {
        [
            "name": zone.name,
            "hourlyRateLKR": zone.hourlyRateLKR,
            "latitude": zone.latitude,
            "longitude": zone.longitude,
            "radiusMeters": zone.radiusMeters,
            "openingHour": zone.openingHour,
            "closingHour": zone.closingHour,
            "maximumStayMinutes": zone.maximumStayMinutes,
            "timeZoneId": zone.timeZoneId,
            "isPublished": zone.isPublished,
            "isActive": zone.isActive,
            "policyVersion": zone.policyVersion
        ]
    }

    private func readZone(
        from document: DocumentSnapshot
    ) throws -> ParkingZone {
        guard let data = document.data(),
              let name = data["name"] as? String,
              let hourlyRateLKR = data["hourlyRateLKR"] as? Int,
              let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let radiusMeters = data["radiusMeters"] as? Double,
              let openingHour = data["openingHour"] as? Int,
              let closingHour = data["closingHour"] as? Int,
              let maximumStayMinutes = data["maximumStayMinutes"] as? Int,
              let timeZoneId = data["timeZoneId"] as? String,
              let isPublished = data["isPublished"] as? Bool,
              let isActive = data["isActive"] as? Bool,
              let policyVersion = data["policyVersion"] as? Int else {
            throw ParkingZoneError.missingDetails
        }

        return ParkingZone(
            id: document.documentID,
            name: name,
            hourlyRateLKR: hourlyRateLKR,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            openingHour: openingHour,
            closingHour: closingHour,
            maximumStayMinutes: maximumStayMinutes,
            timeZoneId: timeZoneId,
            isPublished: isPublished,
            isActive: isActive,
            policyVersion: policyVersion
        )
    }
}

private enum ParkingZoneError: LocalizedError {
    case missingId
    case missingDetails

    var errorDescription: String? {
        switch self {
        case .missingId:
            return "The parking zone needs an ID."

        case .missingDetails:
            return "A parking zone has missing or incorrect details."
        }
    }
}
