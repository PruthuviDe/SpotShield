//
//  BiometricUnlockViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class BiometricUnlockViewModel {
    let profile: UserProfile

    private let biometricManager = BiometricManager.shared

    var password = ""
    var errorMessage = ""
    var isShowingPasswordField = false
    var isCheckingPassword = false
    var isCheckingBiometrics = false

    var biometricDeviceName: String {
        biometricManager.deviceName()
    }

    var isBiometricAvailable: Bool {
        biometricManager.isAvailable()
    }

    var biometricIcon: String {
        biometricDeviceName == "Touch ID" ? "touchid" : "faceid"
    }

    init(profile: UserProfile) {
        self.profile = profile
    }

    func unlockWithBiometrics() async {
        guard !isCheckingBiometrics else { return }

        isCheckingBiometrics = true
        errorMessage = ""
        defer { isCheckingBiometrics = false }

        do {
            try await biometricManager.authenticate(for: profile.id)
        } catch {
            if isAuthenticationCancellation(error) {
                return
            }

            errorMessage = biometricManager.errorMessage(for: error)
        }
    }

    func showPasswordEntry() {
        isShowingPasswordField = true
        errorMessage = ""
    }

    func clearPasswordEntry() {
        password = ""
        isShowingPasswordField = false
    }

    func unlockWithPassword(using appState: AppState) async {
        guard !isCheckingPassword, !password.isEmpty else {
            errorMessage = "Enter your account password to continue."
            return
        }

        isCheckingPassword = true
        errorMessage = ""
        defer { isCheckingPassword = false }

        let didUnlock = await appState.reauthenticateCurrentAccount(
            profile: profile,
            password: password
        )

        if didUnlock {
            password = ""
        } else {
            errorMessage = "That password could not unlock this account. Try again."
        }
    }

    private func isAuthenticationCancellation(_ error: Error) -> Bool {
        guard let authenticationError = error as? LAError else {
            return false
        }

        return authenticationError.code == .userCancel
            || authenticationError.code == .systemCancel
            || authenticationError.code == .appCancel
    }
}
