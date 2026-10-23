//
//  UserProfileRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class UserProfileRepository {
    private let database = Firestore.firestore()

    func saveMotoristDetails(
        userId: String,
        name: String,
        licensePlate: String = ""
    ) async throws {
        let result = try await Functions.functions()
            .httpsCallable("completeMotoristProfile")
            .call(["name": name, "licensePlate": licensePlate])

        guard let data = result.data as? [String: Any],
              data["userId"] as? String == userId else {
            throw NSError(domain: "DriverSetup", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not confirm your profile. Sign in again to check the saved setup."
            ])
        }
    }

    func addMotoristVehicle(licensePlate: String) async throws {
        _ = try await Functions.functions()
            .httpsCallable("addMotoristVehicle")
            .call(["licensePlate": licensePlate])
    }

    func updateMyProfile(
        userId: String,
        name: String,
        licensePlate: String? = nil
    ) async throws -> (vehicleId: String?, licensePlate: String?) {
        var request: [String: Any] = ["name": name]
        if let licensePlate {
            request["licensePlate"] = licensePlate
        }

        let result = try await Functions.functions()
            .httpsCallable("updateMyProfile")
            .call(request)

        guard let data = result.data as? [String: Any],
              data["userId"] as? String == userId else {
            throw NSError(domain: "Profile", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not confirm the profile update. Refresh your profile and try again."
            ])
        }

        return (
            vehicleId: data["vehicleId"] as? String,
            licensePlate: data["licensePlate"] as? String
        )
    }

    func getWardens() async throws -> [UserProfile] {
        let result = try await database
            .collection("users")
            .whereField(
                "role",
                isEqualTo: UserRole.warden.rawValue
            )
            .getDocuments(source: .server)

        var wardens: [UserProfile] = []

        for document in result.documents {
            let data = document.data()

            guard let name = data["name"] as? String,
                  let email = data["email"] as? String else {
                throw NSError(
                    domain: "SpotShield",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "A Warden profile has missing or incorrect details."
                    ]
                )
            }

            let warden = UserProfile(
                id: document.documentID,
                name: name,
                email: email,
                role: .warden,
                primaryVehicleId: nil
            )

            wardens.append(warden)
        }

        return wardens.sorted {
            $0.name < $1.name
        }
    }

    func getProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await database
            .collection("users")
            .document(userId)
            .getDocument()

        guard let data = snapshot.data(),
              let name = data["name"] as? String,
              let email = data["email"] as? String,
              let roleText = data["role"] as? String,
              let role = UserRole(rawValue: roleText) else {
            return nil
        }

        return UserProfile(
            id: userId,
            name: name,
            email: email,
            role: role,
            primaryVehicleId: data["primaryVehicleId"] as? String
        )
    }

    func getVehicle(vehicleId: String) async throws -> Vehicle? {
        let snapshot = try await database
            .collection("vehicles")
            .document(vehicleId)
            .getDocument()

        guard let data = snapshot.data(),
              let ownerUserId = data["ownerUserId"] as? String,
              let licensePlate = data["licensePlate"] as? String,
              let make = data["make"] as? String,
              let model = data["model"] as? String else {
            return nil
        }

        return Vehicle(
            id: vehicleId,
            ownerUserId: ownerUserId,
            licensePlate: licensePlate,
            make: make,
            model: model
        )
    }

}
