//
//  AuthService.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation
import FirebaseAuth

final class AuthService {
    private let auth = Auth.auth()
    private let userProfileRepository: UserProfileRepository

    init(userProfileRepository: UserProfileRepository = UserProfileRepository()) {
        self.userProfileRepository = userProfileRepository
    }

    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }

    func createMotoristAccount(
        name: String,
        email: String,
        password: String,
        licensePlate: String = ""
    ) async throws {
        let newAccount = try await auth.createUser(
            withEmail: email,
            password: password
        )

        do {
            try await userProfileRepository.saveMotoristDetails(
                userId: newAccount.user.uid,
                name: name,
                email: email,
                licensePlate: licensePlate
            )
        } catch {
            try? await newAccount.user.delete()
            throw error
        }
    }

    func signOut() throws {
        try auth.signOut()
    }
}
