//
//  AppState.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import SwiftUI
import FirebaseAuth

enum AuthState {
    case loading
    case signedOut
    case signedIn(UserProfile)
    case error(String)
}

@MainActor
@Observable
final class AppState {
    var authState: AuthState = .loading

    private let auth = Auth.auth()
    private let authService = AuthService()
    private let userProfileRepository = UserProfileRepository()

    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private var profileTask: Task<Void, Never>?
    private var isCreatingAccount = false

    init() {
        authListenerHandle = auth.addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !self.isCreatingAccount else { return }
                self.loadUserProfile()
            }
        }
    }

    isolated deinit {
        profileTask?.cancel()

        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func loadUserProfile() {
        profileTask?.cancel()

        guard let userId = auth.currentUser?.uid else {
            authState = .signedOut
            return
        }

        authState = .loading

        profileTask = Task {
            do {
                let profile = try await userProfileRepository.getProfile(
                    userId: userId
                )

                guard !Task.isCancelled,
                      auth.currentUser?.uid == userId else {
                    return
                }

                if let profile {
                    authState = .signedIn(profile)
                } else {
                    authState = .error(
                        "Your profile is missing or incomplete."
                    )
                }
            } catch {
                guard !Task.isCancelled,
                      auth.currentUser?.uid == userId else {
                    return
                }

                authState = .error(
                    "We couldn't load your profile. Please try again."
                )
            }
        }
    }

    func createMotoristAccount(
        name: String,
        email: String,
        password: String,
        licensePlate: String = ""
    ) async throws {
        isCreatingAccount = true
        profileTask?.cancel()
        authState = .loading

        defer {
            isCreatingAccount = false
        }

        do {
            try await authService.createMotoristAccount(
                name: name,
                email: email,
                password: password,
                licensePlate: licensePlate
            )

            loadUserProfile()
        } catch {
            if auth.currentUser == nil {
                authState = .signedOut
            } else {
                authState = .error(
                    "Your account setup could not finish."
                )
            }

            throw error
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            profileTask?.cancel()
            authState = .signedOut
        } catch {
            authState = .error(
                "We couldn't sign you out. Please try again."
            )
        }
    }
}
