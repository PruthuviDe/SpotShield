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
            .getDocuments(source: .server)

        var zones: [ParkingZone] = []

        for document in result.documents {
            let zone = try readZone(from: document)
            zones.append(zone)
        }

        return zones
    }
    
    func getPublishedZones() async throws -> [ParkingZone] {
        let result = try await database
            .collection("parkingZones")
            .whereField("isPublished", isEqualTo: true)
            .getDocuments(source: .server)

        var zones: [ParkingZone] = []

        for document in result.documents {
            let zone = try readZone(from: document)
            zones.append(zone)
        }

        return zones.sorted {
            $0.name < $1.name
        }
    }
    
    func createZone(zone: ParkingZone) async throws -> ParkingZone {
        guard !zone.id.isEmpty else {
            throw ParkingZoneError.missingId
        }

        var newZone = zone
        newZone.isPublished = false
        newZone.isActive = false
        newZone.wardenAssignmentId = nil
        newZone.policyVersion = 1

        var data = zoneDetails(zone: newZone)
        data["isPublished"] = false
        data["isActive"] = false

        try await database
            .collection("parkingZones")
            .document(newZone.id)
            .setData(data)

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
            .updateData(zoneDetails(zone: updatedZone))

        return updatedZone
    }

    func publishZone(
        zone: ParkingZone,
        assignment: WardenAssignment
    ) async throws -> ParkingZone {
        guard !zone.id.isEmpty else {
            throw ParkingZoneError.missingId
        }

        guard !assignment.id.isEmpty,
              assignment.parkingZoneId == zone.id,
              assignment.isActive,
              assignment.endedAt == nil else {
            throw ParkingZoneError.invalidAssignment
        }

        var updatedZone = zone
        updatedZone.isPublished = true
        updatedZone.isActive = true
        updatedZone.wardenAssignmentId = assignment.id
        updatedZone.policyVersion += 1

        let data: [String: Any] = [
            "isPublished": true,
            "isActive": true,
            "wardenAssignmentId": assignment.id,
            "policyVersion": updatedZone.policyVersion
        ]

        try await database
            .collection("parkingZones")
            .document(updatedZone.id)
            .updateData(data)

        return updatedZone
    }

    func deactivateZone(zone: ParkingZone) async throws -> ParkingZone {
        guard !zone.id.isEmpty else {
            throw ParkingZoneError.missingId
        }

        var updatedZone = zone
        updatedZone.isActive = false
        updatedZone.policyVersion += 1

        let data: [String: Any] = [
            "isActive": false,
            "policyVersion": updatedZone.policyVersion
        ]

        try await database
            .collection("parkingZones")
            .document(updatedZone.id)
            .updateData(data)

        return updatedZone
    }

    private func zoneDetails(zone: ParkingZone) -> [String: Any] {
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

        var assignmentId: String? = nil

        if let savedValue = data["wardenAssignmentId"] {
            guard let savedId = savedValue as? String,
                  !savedId.isEmpty else {
                throw ParkingZoneError.missingDetails
            }

            assignmentId = savedId
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
            policyVersion: policyVersion,
            wardenAssignmentId: assignmentId
        )
    }
}

private enum ParkingZoneError: LocalizedError {
    case missingId
    case missingDetails
    case invalidAssignment

    var errorDescription: String? {
        switch self {
        case .missingId:
            return "The parking zone needs an ID."

        case .missingDetails:
            return "A parking zone has missing or incorrect details."

        case .invalidAssignment:
            return "Choose an active Warden assignment for this zone."
        }
    }
}
