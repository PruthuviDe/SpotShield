//
//  WardenObservationRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation
import FirebaseFunctions
import FirebaseAuth

final class WardenObservationRepository {
    private lazy var functions = Functions.functions()

    func getZones() async throws -> [WardenPatrolZone] {
        let result = try await functions
            .httpsCallable("getWardenZones")
            .call()

        guard let data = result.data as? [String: Any],
              let rows = data["zones"] as? [[String: Any]] else {
            throw repositoryError("Could not load your assigned zones.")
        }

        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let name = row["name"] as? String else {
                return nil
            }

            return WardenPatrolZone(id: id, name: name)
        }
    }

    func checkPlate(
        zoneId: String,
        licensePlate: String
    ) async throws -> PlateCheckResult {
        let result = try await functions
            .httpsCallable("checkParkingPlate")
            .call([
                "parkingZoneId": zoneId,
                "licensePlate": licensePlate
            ])

        return try readCheck(from: result.data)
    }

    func pendingSubmission() -> ObservationSubmission? {
        guard let userId = Auth.auth().currentUser?.uid,
              let data = UserDefaults.standard.data(forKey: "warden.pendingObservation.\(userId)") else {
            return nil
        }
        return try? JSONDecoder().decode(ObservationSubmission.self, from: data)
    }

    func submitObservation(zoneId: String, licensePlate: String, notes: String) async throws {
        guard pendingSubmission() == nil else {
            throw repositoryError("Resolve your pending observation before submitting another.")
        }
        let submission = ObservationSubmission(
            id: UUID().uuidString,
            zoneId: zoneId,
            licensePlate: licensePlate,
            notes: notes
        )
        let key = try submissionKey()
        UserDefaults.standard.set(try JSONEncoder().encode(submission), forKey: key)
        try await sendSubmission(submission)
    }

    func retryPendingSubmission() async throws {
        guard let submission = pendingSubmission() else { return }
        try await sendSubmission(submission)
    }

    private func sendSubmission(_ submission: ObservationSubmission) async throws {
        let key = try submissionKey()
        do {
            let result = try await functions.httpsCallable("submitWardenObservation").call([
                "parkingZoneId": submission.zoneId,
                "licensePlate": submission.licensePlate,
                "notes": submission.notes,
                "operationId": submission.id,
                "isConfirmed": true
            ])
            guard let data = result.data as? [String: Any],
                  data["observationId"] as? String == submission.id else {
                throw repositoryError("The saved observation could not be confirmed. Retry the pending submission.")
            }
            UserDefaults.standard.removeObject(forKey: key)
        } catch {
            let savedError = error as NSError
            if savedError.domain == FunctionsErrorDomain,
               let code = FunctionsErrorCode(rawValue: savedError.code),
               [.invalidArgument, .failedPrecondition, .permissionDenied, .alreadyExists].contains(code) {
                UserDefaults.standard.removeObject(forKey: key)
            }
            throw error
        }
    }

    private func submissionKey() throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw repositoryError("Please sign in again.")
        }
        return "warden.pendingObservation.\(userId)"
    }

    func getWardenObservations() async throws -> [WardenObservation] {
        let result = try await functions
            .httpsCallable("getWardenObservations")
            .call()

        return try readObservations(from: result.data)
    }

    func getPendingObservations() async throws -> [WardenObservation] {
        let result = try await functions
            .httpsCallable("getPendingWardenObservations")
            .call()

        return try readObservations(from: result.data)
    }

    func getReviewedObservations() async throws -> [WardenObservation] {
        let result = try await functions.httpsCallable("getReviewedWardenObservations").call()
        return try readObservations(from: result.data)
    }

    func getReview(id: String) async throws -> ObservationReview {
        let result = try await functions.httpsCallable("getObservationReview").call(["observationId": id])
        guard let data = result.data as? [String: Any],
              let canIssue = data["canIssueTicket"] as? Bool,
              let reason = data["issueBlockedReason"] as? String,
              let known = data["recipientKnown"] as? Bool else {
            throw repositoryError("Could not check the current case. Please refresh.")
        }
        return ObservationReview(
            check: try readCheck(from: data), canIssueTicket: canIssue,
            issueBlockedReason: reason, recipientKnown: known
        )
    }

    func reviewObservation(
        id: String,
        issueTicket: Bool,
        reason: String
    ) async throws {
        let result = try await functions
            .httpsCallable("reviewWardenObservation")
            .call([
                "observationId": id,
                "action": issueTicket ? "issueTicket" : "dismiss",
                "reason": reason
            ])
        guard let data = result.data as? [String: Any],
              data["observationId"] as? String == id,
              data["status"] as? String == (issueTicket ? "Ticket Issued" : "Dismissed") else {
            throw repositoryError("Could not confirm the decision. Refresh to check the saved result.")
        }
    }

    private func readObservations(from value: Any) throws -> [WardenObservation] {
        guard let data = value as? [String: Any],
              let rows = data["observations"] as? [[String: Any]] else {
            throw repositoryError("Could not load the observations.")
        }

        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let wardenUserId = row["wardenUserId"] as? String,
                  let parkingZoneId = row["parkingZoneId"] as? String,
                  let zoneName = row["zoneName"] as? String,
                  let licensePlate = row["licensePlate"] as? String,
                  let statusText = row["reviewStatus"] as? String,
                  let status = ObservationStatus(rawValue: statusText),
                  let isViolation = row["isViolation"] as? Bool,
                  let parkingStatus = row["parkingStatus"] as? String else {
                return nil
            }

            let millis = (row["observedAtMillis"] as? NSNumber)?.doubleValue ?? 0

            return WardenObservation(
                id: id,
                wardenUserId: wardenUserId,
                parkingZoneId: parkingZoneId,
                zoneName: zoneName,
                licensePlate: licensePlate,
                observedAt: Date(timeIntervalSince1970: millis / 1000),
                reviewStatus: status,
                notes: row["notes"] as? String,
                isViolation: isViolation,
                parkingStatus: parkingStatus,
                ticketId: row["ticketId"] as? String,
                decisionReason: row["decisionReason"] as? String
            )
        }
    }

    private func readCheck(from value: Any) throws -> PlateCheckResult {
        guard let data = value as? [String: Any],
              let statusText = data["status"] as? String,
              let status = ParkingStatus(rawValue: statusText),
              let message = data["parkingStatus"] as? String,
              let millis = data["checkedAtMillis"] as? NSNumber else {
            throw repositoryError("Could not verify this plate. Please check again.")
        }
        return PlateCheckResult(
            status: status, parkingStatus: message,
            checkedAt: Date(timeIntervalSince1970: millis.doubleValue / 1000)
        )
    }

    private func repositoryError(_ message: String) -> NSError {
        NSError(
            domain: "WardenObservationRepository",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
