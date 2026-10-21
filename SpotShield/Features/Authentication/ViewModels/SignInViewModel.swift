//
//  SignInViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-11.
//

import Foundation
import Observation

@MainActor
@Observable
final class SignInViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var isSendingPasswordReset = false
    var errorMessage = ""
    var successMessage = ""

    private let authService = AuthService()

    var isBusy: Bool {
        isLoading || isSendingPasswordReset
    }

    func signIn() async {
        guard !isBusy else { return }

        errorMessage = ""
        successMessage = ""

        let cleanEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.signIn(
                email: cleanEmail,
                password: password
            )
            password = ""
        } catch {
            errorMessage = "Sign in failed. Check your details and internet connection, then try again."
        }
    }

    func sendPasswordReset() async {
        guard !isBusy else { return }

        errorMessage = ""
        successMessage = ""

        let cleanEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanEmail.isEmpty else {
            errorMessage = "Enter your email address first."
            return
        }

        isSendingPasswordReset = true
        defer { isSendingPasswordReset = false }

        do {
            try await authService.sendPasswordReset(email: cleanEmail)
            successMessage = "If an account exists for this email, you will receive a password reset link."
        } catch {
            errorMessage = "Could not send the reset link. Check the email and your connection, then try again."
        }
    }
}
