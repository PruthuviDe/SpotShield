//
//  WalletViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-18.
//

import Foundation
import Observation

@MainActor
@Observable
final class WalletViewModel {
    var wallet: Wallet?
    var isLoading = false
    var errorMessage = ""

    private let profile: UserProfile
    private let repository = WalletRepository()

    init(profile: UserProfile) {
        self.profile = profile
    }

    func loadWallet() async {
        guard !isLoading, !Task.isCancelled else { return }

        wallet = nil
        errorMessage = ""

        guard profile.role == .motorist else {
            errorMessage = "Wallets are available to Drivers only."
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        do {
            try await repository.createWalletIfNeeded(
                userId: profile.id
            )

            guard !Task.isCancelled else { return }

            let savedWallet = try await repository.getWallet(
                userId: profile.id
            )

            guard !Task.isCancelled else { return }

            guard let savedWallet else {
                errorMessage = "Your wallet could not be found. Please try again."
                return
            }

            wallet = savedWallet
        } catch {
            guard !Task.isCancelled else { return }

            errorMessage = "Could not load your wallet. Please try again."
        }
    }
}
