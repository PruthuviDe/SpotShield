//
//  WardenAssignmentRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import Foundation
import FirebaseFirestore

final class WardenAssignmentRepository {
    private let database = Firestore.firestore()

    func getAssignments() async throws -> [WardenAssignment] {
        let result = try await database
            .collection("wardenAssignments")
            .order(by: "assignedAt", descending: true)
            .getDocuments(source: .server)

        var assignments: [WardenAssignment] = []

        for document in result.documents {
            let assignment = try readAssignment(from: document)
            assignments.append(assignment)
        }

        return assignments
    }
    
    func createAssignment(
        assignmentId: String,
        parkingZoneId: String,
        wardenUserId: String,
        adminUserId: String
    ) async throws {
        guard !assignmentId.isEmpty,
              !parkingZoneId.isEmpty,
              !wardenUserId.isEmpty,
              !adminUserId.isEmpty else {
            throw WardenAssignmentError.missingDetails
        }

        let zoneReference = database
            .collection("parkingZones")
            .document(parkingZoneId)
        let zoneSnapshot = try await zoneReference.getDocument(source: .server)

        guard let zoneData = zoneSnapshot.data() else {
            throw WardenAssignmentError.missingDetails
        }

        let assignmentReference = database
            .collection("wardenAssignments")
            .document(assignmentId)
        let data: [String: Any] = [
            "parkingZoneId": parkingZoneId,
            "wardenUserId": wardenUserId,
            "assignedByUserId": adminUserId,
            "assignedAt": FieldValue.serverTimestamp(),
            "isActive": true
        ]

        let batch = database.batch()
        batch.setData(data, forDocument: assignmentReference)

        if zoneData["isPublished"] as? Bool == true,
           zoneData["isActive"] as? Bool == true {
            guard let policyVersion = zoneData["policyVersion"] as? Int else {
                throw WardenAssignmentError.missingDetails
            }

            if let currentAssignmentId = zoneData["wardenAssignmentId"] as? String,
               currentAssignmentId != assignmentId {
                let currentAssignmentReference = database
                    .collection("wardenAssignments")
                    .document(currentAssignmentId)
                let currentAssignment = try await currentAssignmentReference.getDocument(source: .server)

                if currentAssignment.exists,
                   currentAssignment.data()?["isActive"] as? Bool == true,
                   currentAssignment.data()?["endedAt"] == nil,
                   currentAssignment.data()?["parkingZoneId"] as? String == parkingZoneId {
                    batch.updateData(
                        [
                            "isActive": false,
                            "endedAt": FieldValue.serverTimestamp()
                        ],
                        forDocument: currentAssignmentReference
                    )
                }
            }

            batch.updateData(
                [
                    "wardenAssignmentId": assignmentId,
                    "policyVersion": policyVersion + 1
                ],
                forDocument: zoneReference
            )
        }

        try await batch.commit()
    }

    func endAssignment(assignmentId: String) async throws {
        guard !assignmentId.isEmpty else {
            throw WardenAssignmentError.missingDetails
        }

        let data: [String: Any] = [
            "isActive": false,
            "endedAt": FieldValue.serverTimestamp()
        ]

        try await database
            .collection("wardenAssignments")
            .document(assignmentId)
            .updateData(data)
    }

    private func readAssignment(
        from document: DocumentSnapshot
    ) throws -> WardenAssignment {
        guard let data = document.data(),
              let parkingZoneId = data["parkingZoneId"] as? String,
              let wardenUserId = data["wardenUserId"] as? String,
              let assignedByUserId = data["assignedByUserId"] as? String,
              let assignedAt = data["assignedAt"] as? Timestamp,
              let isActive = data["isActive"] as? Bool else {
            throw WardenAssignmentError.missingDetails
        }

        var endedAt: Date? = nil

        if isActive {
            guard data["endedAt"] == nil else {
                throw WardenAssignmentError.missingDetails
            }
        } else {
            guard let savedEndTime = data["endedAt"] as? Timestamp else {
                throw WardenAssignmentError.missingDetails
            }

            endedAt = savedEndTime.dateValue()
        }

        return WardenAssignment(
            id: document.documentID,
            parkingZoneId: parkingZoneId,
            wardenUserId: wardenUserId,
            assignedByUserId: assignedByUserId,
            assignedAt: assignedAt.dateValue(),
            isActive: isActive,
            endedAt: endedAt
        )
    }
}

private enum WardenAssignmentError: LocalizedError {
    case missingDetails

    var errorDescription: String? {
        switch self {
        case .missingDetails:
            return "Assignment details are missing or incorrect."
        }
    }
}
