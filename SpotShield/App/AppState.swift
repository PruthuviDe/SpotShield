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
    case wardenRequest(WardenRequest)
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
    
    private let wardenRequestRepository = WardenRequestRepository()

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
                // First, look for the user's normal profile
                let profile = try await userProfileRepository.getProfile(
                    userId: userId
                )

                guard !Task.isCancelled,
                      auth.currentUser?.uid == userId else {
                    return
                }

                if let profile {
                    authState = .signedIn(profile)
                    return
                }

                let request = try await wardenRequestRepository.getRequest(
                    userId: userId
                )

                guard !Task.isCancelled,
                      auth.currentUser?.uid == userId else {
                    return
                }

                guard let request else {
                    authState = .error(
                        "Your account details are missing or incomplete."
                    )
                    return
                }

                if request.status == .approved {
                    authState = .error(
                        "Your request was approved, but your Warden profile is missing. Please contact Admin."
                    )
                    return
                }

                authState = .wardenRequest(request)
            } catch {
                guard !Task.isCancelled,
                      auth.currentUser?.uid == userId else {
                    return
                }

                authState = .error(
                    "We couldn't load your account details. Please try again."
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

    
    func createWardenRequest(
        name: String,
        email: String,
        password: String
    ) async throws {
        isCreatingAccount = true
        profileTask?.cancel()

        defer {
            isCreatingAccount = false
        }

        do {
            try await authService.createWardenRequest(
                name: name,
                email: email,
                password: password
            )

            loadUserProfile()
        } catch {
            if auth.currentUser == nil {
                authState = .signedOut
            } else {
                authState = .error(
                    "Your application setup could not finish."
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

