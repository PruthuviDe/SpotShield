//
//  AppState.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum AuthState {
    case loading
    case signedOut
    case signedIn(UserProfile)
}

@Observable
final class AppState {
    var authState: AuthState = .loading
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    init() {
        startListeningToAuth()
    }

    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func startListeningToAuth() {
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }

            guard let user = firebaseUser else {
                self.authState = .signedOut
                return
            }

            self.loadUserProfile(userId: user.uid)
        }
    }

    func loadUserProfile(userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("Error loading profile: \(error.localizedDescription)")
                self.authState = .signedOut
                return
            }

            guard let data = snapshot?.data(),
                  let name = data["name"] as? String,
                  let email = data["email"] as? String,
                  let roleString = data["role"] as? String,
                  let role = UserRole(rawValue: roleString) else {
                self.authState = .signedOut
                return
            }

            let primaryVehicleId = data["primaryVehicleId"] as? String
            let profile = UserProfile(
                id: userId,
                name: name,
                email: email,
                role: role,
                primaryVehicleId: primaryVehicleId
            )

            self.authState = .signedIn(profile)
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            authState = .signedOut
        } catch {
            print("Sign out error: \(error.localizedDescription)")
        }
    }
}
