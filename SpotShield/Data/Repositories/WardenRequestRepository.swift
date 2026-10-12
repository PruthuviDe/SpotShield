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
            let snapshot = try await database
                .collection("wardenRequests")
                .document(userId)
                .getDocument()

            guard let data = snapshot.data(),
                  let name = data["name"] as? String,
                  let email = data["email"] as? String,
                  let statusText = data["status"] as? String,
                  let status = WardenRequestStatus(rawValue: statusText),
                  let createdAt = data["createdAt"] as? Timestamp else {
                return nil
            }

            let reviewedAt = data["reviewedAt"] as? Timestamp

            return WardenRequest(
                id: userId,
                name: name,
                email: email,
                status: status,
                createdAt: createdAt.dateValue(),
                reviewedByUserId: data["reviewedByUserId"] as? String,
                reviewedAt: reviewedAt?.dateValue()
            )
        }
    }
