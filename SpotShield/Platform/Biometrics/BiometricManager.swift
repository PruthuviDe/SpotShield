//
//  BiometricManager.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//


import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class BiometricManager {
    static let shared = BiometricManager()

    private(set) var unlockedUserID: String?
    private(set) var isAuthenticating = false

    private let defaults = UserDefaults.standard
    private let preferenceKey = "spotshield.biometric.enabled."

    private init() { }

    func isEnabled(for userID: String) -> Bool {
        defaults.bool(forKey: preferenceKey + userID)
    }

    func deviceName() -> String {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            return "Biometric unlock unavailable"
        }

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric unlock"
        }
    }

    func isAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }

    func enable(for userID: String) async throws {
        try await authenticateDevice(reason: "Enable secure access to SpotShield.")
        defaults.set(true, forKey: preferenceKey + userID)
        unlockedUserID = userID
    }

    func disable(for userID: String) {
        defaults.removeObject(forKey: preferenceKey + userID)
    }

    func authenticate(for userID: String) async throws {
        try await authenticateDevice(reason: "Unlock your SpotShield account.")
        unlockedUserID = userID
    }

    func lock(for userID: String) {
        guard isEnabled(for: userID) else { return }
        unlockedUserID = nil
    }

    func unlockAfterPassword(for userID: String) {
        unlockedUserID = userID
    }

    func clearUnlockedUser() {
        unlockedUserID = nil
    }

    func errorMessage(for error: Error) -> String {
        guard let authenticationError = error as? LAError else {
            return "Biometric authentication could not be completed. Use your account password."
        }

        switch authenticationError.code {
        case .biometryNotEnrolled:
            return "Set up Face ID or Touch ID in iPhone Settings, then try again."
        case .biometryLockout:
            return "Biometrics are locked. Unlock with your account password."
        case .biometryNotAvailable, .passcodeNotSet:
            return "Biometric unlock is unavailable. Use your account password."
        case .userCancel, .systemCancel, .appCancel:
            return "Authentication was cancelled. Try again or use your account password."
        default:
            return "Biometric authentication failed. Try again or use your account password."
        }
    }

    private func authenticateDevice(reason: String) async throws {
        guard !isAuthenticating else {
            throw LAError(.appCancel)
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        var availabilityError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &availabilityError
        ) else {
            throw availabilityError ?? LAError(.biometryNotAvailable)
        }

        try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
}
