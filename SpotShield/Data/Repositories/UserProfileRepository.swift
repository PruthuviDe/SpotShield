//
//  UserProfileRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation
import FirebaseFirestore

final class UserProfileRepository {
    private let database = Firestore.firestore()

    func saveMotoristDetails(
        userId: String,
        name: String,
        email: String,
        licensePlate: String = ""
    ) async throws {
        let batch = database.batch()

        var profile = UserProfile(
            id: userId,
            name: name,
            email: email,
            role: .motorist,
            primaryVehicleId: nil
        )

        let plate = licensePlate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if !plate.isEmpty {
            let vehicleDocument = database
                .collection("vehicles")
                .document()

            let vehicle = Vehicle(
                id: vehicleDocument.documentID,
                ownerUserId: userId,
                licensePlate: plate,
                make: "",
                model: ""
            )

            profile.primaryVehicleId = vehicle.id

            batch.setData(
                vehicleData(vehicle),
                forDocument: vehicleDocument,
                merge: true
            )
        }

        let profileDocument = database
            .collection("users")
            .document(userId)

        batch.setData(
            profileData(profile),
            forDocument: profileDocument,
            merge: true
        )

        try await batch.commit()
    }

    func saveProfile(profile: UserProfile) async throws {
        try await database
            .collection("users")
            .document(profile.id)
            .setData(profileData(profile), merge: true)
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

    func saveVehicle(vehicle: Vehicle) async throws {
        try await database
            .collection("vehicles")
            .document(vehicle.id)
            .setData(vehicleData(vehicle), merge: true)
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

    private func profileData(_ profile: UserProfile) -> [String: Any] {
        var data: [String: Any] = [
            "name": profile.name,
            "email": profile.email,
            "role": profile.role.rawValue
        ]

        if let vehicleId = profile.primaryVehicleId {
            data["primaryVehicleId"] = vehicleId
        }

        return data
    }

    private func vehicleData(_ vehicle: Vehicle) -> [String: Any] {
        [
            "ownerUserId": vehicle.ownerUserId,
            "licensePlate": vehicle.licensePlate,
            "make": vehicle.make,
            "model": vehicle.model
        ]
    }
}
