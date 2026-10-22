//
//  AuthService.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation
import FirebaseAuth
import FirebaseFunctions

final class AuthService {
    private let auth = Auth.auth()
    private let userProfileRepository: UserProfileRepository
    private let wardenRequestRepository = WardenRequestRepository()

    init(userProfileRepository: UserProfileRepository = UserProfileRepository()) {
        self.userProfileRepository = userProfileRepository
    }

    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    func reauthenticate(email: String, password: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthServiceError.noSignedInUser
        }

        guard user.email?.caseInsensitiveCompare(email) == .orderedSame else {
            throw AuthServiceError.emailDoesNotMatch
        }

        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: password
        )
        try await user.reauthenticate(with: credential)
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
                licensePlate: licensePlate
            )
        } catch {
            let savedError = error as NSError
            if savedError.domain == FunctionsErrorDomain,
               let code = FunctionsErrorCode(rawValue: savedError.code),
               [.invalidArgument, .alreadyExists, .permissionDenied, .failedPrecondition].contains(code) {
                try? await newAccount.user.delete()
            }
            throw error
        }
    }
    
    func createWardenRequest(
        name: String,
        email: String,
        password: String
    ) async throws {
        let newAccount = try await auth.createUser(
            withEmail: email,
            password: password
        )

        do {
            try await wardenRequestRepository.createRequest(
                userId: newAccount.user.uid,
                name: name,
                email: email
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

private enum AuthServiceError: Error {
    case noSignedInUser
    case emailDoesNotMatch
}
