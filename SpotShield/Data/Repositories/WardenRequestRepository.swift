//
//  WardenRequestRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-12.
//

import Foundation
import FirebaseFirestore

final class WardenRequestRepository {
    private let database = Firestore.firestore()

    func createRequest(
        userId: String,
        name: String,
        email: String
    ) async throws {
        let data: [String: Any] = [
            "name": name,
            "email": email,
            "status": WardenRequestStatus.waiting.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await database
            .collection("wardenRequests")
            .document(userId)
            .setData(data)
    }

    func getRequest(userId: String) async throws -> WardenRequest? {
        let document = try await database
            .collection("wardenRequests")
            .document(userId)
            .getDocument()

        guard document.exists else {
            return nil
        }

        return try readRequest(from: document)
    }

    func getWaitingRequests() async throws -> [WardenRequest] {
        let result = try await database
            .collection("wardenRequests")
            .whereField(
                "status",
                isEqualTo: WardenRequestStatus.waiting.rawValue
            )
            .getDocuments()

        var requests: [WardenRequest] = []

        for document in result.documents {
            let request = try readRequest(from: document)
            requests.append(request)
        }

        return requests
    }

    func approveRequest(
        request: WardenRequest,
        adminUserId: String
    ) async throws {
        let profileDocument = database
            .collection("users")
            .document(request.id)

        let requestDocument = database
            .collection("wardenRequests")
            .document(request.id)

        let profileData: [String: Any] = [
            "name": request.name,
            "email": request.email,
            "role": UserRole.warden.rawValue
        ]

        let decisionData: [String: Any] = [
            "status": WardenRequestStatus.approved.rawValue,
            "reviewedByUserId": adminUserId,
            "reviewedAt": FieldValue.serverTimestamp()
        ]

        let batch = database.batch()

        batch.setData(
            profileData,
            forDocument: profileDocument
        )

        batch.updateData(
            decisionData,
            forDocument: requestDocument
        )

        try await batch.commit()
    }

    func rejectRequest(
        userId: String,
        adminUserId: String
    ) async throws {
        let decisionData: [String: Any] = [
            "status": WardenRequestStatus.rejected.rawValue,
            "reviewedByUserId": adminUserId,
            "reviewedAt": FieldValue.serverTimestamp()
        ]

        try await database
            .collection("wardenRequests")
            .document(userId)
            .updateData(decisionData)
    }

    private func readRequest(
        from document: DocumentSnapshot
    ) throws -> WardenRequest {
        guard let data = document.data(),
              let name = data["name"] as? String,
              let email = data["email"] as? String,
              let statusText = data["status"] as? String,
              let status = WardenRequestStatus(rawValue: statusText),
              let createdAt = data["createdAt"] as? Timestamp else {
            throw NSError(
                domain: "SpotShield",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "An application has missing or incorrect details."
                ]
            )
        }

        let reviewedAt = data["reviewedAt"] as? Timestamp

        return WardenRequest(
            id: document.documentID,
            name: name,
            email: email,
            status: status,
            createdAt: createdAt.dateValue(),
            reviewedByUserId: data["reviewedByUserId"] as? String,
            reviewedAt: reviewedAt?.dateValue()
        )
    }
}
