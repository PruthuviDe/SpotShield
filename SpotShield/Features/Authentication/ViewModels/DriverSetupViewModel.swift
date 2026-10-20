//
//  DriverSetupViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation
import Observation
import FirebaseAuth

@MainActor
@Observable
final class DriverSetupViewModel {
    var name = ""
    var licensePlate = ""
    var isSaving = false
    var errorMessage = ""
    let profile: UserProfile?
    private let repository = UserProfileRepository()

    init(profile: UserProfile?) {
        self.profile = profile
    }

    func save() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = ""
        defer { isSaving = false }
        do {
            if profile != nil {
                try await repository.addMotoristVehicle(licensePlate: licensePlate)
            } else {
                guard let user = Auth.auth().currentUser else {
                    errorMessage = "Please sign in again."
                    return false
                }
                try await repository.saveMotoristDetails(
                    userId: user.uid, name: name, licensePlate: licensePlate
                )
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
