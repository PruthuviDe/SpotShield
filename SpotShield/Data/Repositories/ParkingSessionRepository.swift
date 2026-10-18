//
//  ParkingSessionRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-18.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class ParkingSessionRepository {
    private lazy var database = Firestore.firestore()
    private lazy var functions = Functions.functions()

    func startParking(
        parkingZoneId: String,
        vehicleId: String,
        durationMinutes: Int,
        policyVersion: Int,
        isParkedHere: Bool,
        operationId: String
    ) async throws -> String {
        guard isValidId(parkingZoneId),
              isValidId(vehicleId),
              isValidId(operationId),
              [30, 60, 120].contains(durationMinutes),
              policyVersion > 0,
              isParkedHere else {
            throw ParkingSessionError.invalidParkingDetails
        }

        let result = try await functions
            .httpsCallable("startParking")
            .call([
                "parkingZoneId": parkingZoneId,
                "vehicleId": vehicleId,
                "durationMinutes": durationMinutes,
                "policyVersion": policyVersion,
                "isParkedHere": isParkedHere,
                "operationId": operationId
            ])

        guard let data = result.data as? [String: Any],
              let sessionId = data["sessionId"] as? String,
              isValidId(sessionId) else {
            throw ParkingSessionError.invalidResponse
        }

        return sessionId
    }

    func endParking(sessionId: String) async throws {
        guard isValidId(sessionId) else {
            throw ParkingSessionError.invalidSession
        }

        let result = try await functions
            .httpsCallable("endParking")
            .call([
                "sessionId": sessionId
            ])

        guard let data = result.data as? [String: Any],
              let savedSessionId = data["sessionId"] as? String,
              savedSessionId == sessionId,
              let ended = data["ended"] as? Bool,
              ended else {
            throw ParkingSessionError.invalidResponse
        }
    }

    func getActiveSession(userId: String) async throws -> ParkingSession? {
        guard isValidId(userId) else {
            throw ParkingSessionError.invalidUserId
        }

        let document = try await database
            .collection("activeParkingSessions")
            .document(userId)
            .getDocument(source: .server)

        guard document.exists else {
            return nil
        }

        guard let data = document.data(),
              let ownerUserId = data["userId"] as? String,
              ownerUserId == userId,
              let vehicleId = data["vehicleId"] as? String,
              isValidId(vehicleId),
              let sessionId = data["parkingSessionId"] as? String,
              isValidId(sessionId) else {
            throw ParkingSessionError.invalidSession
        }

        guard let session = try await getSession(
            sessionId: sessionId,
            userId: userId
        ), session.vehicleId == vehicleId else {
            throw ParkingSessionError.invalidSession
        }

        return session.isActive ? session : nil
    }

    func getSession(
        sessionId: String,
        userId: String
    ) async throws -> ParkingSession? {
        guard isValidId(userId) else {
            throw ParkingSessionError.invalidUserId
        }

        guard isValidId(sessionId) else {
            throw ParkingSessionError.invalidSession
        }

        let document = try await database
            .collection("parkingSessions")
            .document(sessionId)
            .getDocument(source: .server)

        guard document.exists else {
            return nil
        }

        guard var data = document.data() else {
            throw ParkingSessionError.invalidSession
        }

        data["id"] = document.documentID

        let session = try Firestore.Decoder().decode(
            ParkingSession.self,
            from: data
        )

        guard session.userId == userId,
              isValidId(session.vehicleId),
              isValidId(session.parkingZoneId),
              isValidId(session.operationId),
              !session.zoneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !session.licensePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              session.paidUntil > session.startTime,
              session.durationMinutes > 0,
              session.hourlyRateLKR > 0,
              session.totalPaidLKR > 0,
              session.policyVersion > 0 else {
            throw ParkingSessionError.invalidSession
        }

        if let endTime = session.endTime {
            guard !session.isActive, endTime >= session.startTime else {
                throw ParkingSessionError.invalidSession
            }
        }

        return session
    }

    private func isValidId(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && !value.contains("/")
    }
}

private enum ParkingSessionError: LocalizedError {
    case invalidUserId
    case invalidParkingDetails
    case invalidResponse
    case invalidSession

    var errorDescription: String? {
        switch self {
        case .invalidUserId:
            return "Your user ID is missing or incorrect."
        case .invalidParkingDetails:
            return "Choose your parking time and confirm that you are parked here."
        case .invalidResponse:
            return "Could not confirm the parking result. Please refresh your parking session."
        case .invalidSession:
            return "Your parking session has missing or incorrect details."
        }
    }
}
