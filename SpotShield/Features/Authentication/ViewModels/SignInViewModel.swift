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

final class SignInViewModel{
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage = ""
    
    private let authService = AuthService()
    
    func signIn() async {
        
        guard !isLoading else { return }
        
        errorMessage = ""
        
        let cleanEmail = email.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                guard !cleanEmail.isEmpty, !password.isEmpty else {
                    errorMessage = "Please enter your email and password."
                    return
                }
        
        isLoading = true
        
        defer {
                    isLoading = false
                }

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
}
