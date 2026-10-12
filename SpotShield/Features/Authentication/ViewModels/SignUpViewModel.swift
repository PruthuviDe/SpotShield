//
//  SignUpViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-12.
//

import Foundation
import Observation


@MainActor
@Observable
final class SignUpViewModel {
    var fullName = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    var licensePlate = ""
    
    var isLoading = false
    var errorMessage = ""
    
    func createAccount(appState: AppState) async {
        guard !isLoading else { return }

                errorMessage = ""

                let cleanName = fullName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                let cleanEmail = email.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                guard !cleanName.isEmpty,
                      !cleanEmail.isEmpty,
                      !password.isEmpty else {
                    errorMessage = "Please enter your name, email and password."
                    return
                }

                guard password.count >= 6 else {
                    errorMessage = "Use a password with at least 6 characters."
                    return
                }

                guard password == confirmPassword else {
                    errorMessage = "Your passwords do not match."
                    return
                }

                isLoading = true
        
        defer {
                    isLoading = false
                }

                do {
                    try await appState.createMotoristAccount(
                        name: cleanName,
                        email: cleanEmail,
                        password: password,
                        licensePlate: licensePlate
                    )

                    password = ""
                    confirmPassword = ""
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
