//
//  UserProfileRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation
import FirebaseFirestore

final class UserProfileRepository {
    private let db = Firestore.firestore()
    
    func saveProfile(profile: UserProfile) async throws {
        var data: [String: Any] = [
            "name": profile.name,
            "email": profile.email,
            "role": profile.role.rawValue
        ]
        if let vehicleId = profile.primaryVehicleId {
            data["primaryVehicleId"] = vehicleId
        }
        
        try await db.collection("users").document(profile.id).setData(data, merge: true)
    }
    
    func getProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data() else { return nil }
        
        guard let name = data["name"] as? String,
              let email = data["email"] as? String,
              let roleText = data["role"] as? String,
              let role = UserRole(rawValue: roleText) else {
            return nil
        }
        
        let primaryVehicleId = data["primaryVehicleId"] as? String
        
        return UserProfile(
            id: userId,
            name: name,
            email: email,
            role: role,
            primaryVehicleId: primaryVehicleId
        )
    }
    
    func saveVehicle(vehicle: Vehicle) async throws {
        let data: [String: Any] = [
            "ownerUserId": vehicle.ownerUserId,
            "licensePlate": vehicle.licensePlate,
            "make": vehicle.make,
            "model": vehicle.model
        ]
        
        try await db.collection("vehicles").document(vehicle.id).setData(data, merge: true)
    }
    
    func getVehicle(vehicleId: String) async throws -> Vehicle? {
        let snapshot = try await db.collection("vehicles").document(vehicleId).getDocument()
        guard let data = snapshot.data() else { return nil }
        
        guard let ownerUserId = data["ownerUserId"] as? String,
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
