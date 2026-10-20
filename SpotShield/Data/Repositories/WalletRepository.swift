//
//  WalletRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-18.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class WalletRepository {
    private lazy var database = Firestore.firestore()

    func getWallet(userId: String) async throws -> Wallet? {
        guard !userId.isEmpty,
              !userId.contains("/") else {
            throw WalletError.invalidUserId
        }

        let document = try await database
            .collection("wallets")
            .document(userId)
            .getDocument(source: .server)

        guard document.exists else {
            return nil
        }

        guard let data = document.data(),
              let ownerUserId = data["userId"] as? String,
              ownerUserId == userId,
              let balance = data["balanceLKR"] as? Int,
              balance >= 0,
              let autoDeductEnabled = data["autoDeductEnabled"] as? Bool else {
            throw WalletError.invalidDetails
        }

        return Wallet(
            id: document.documentID,
            userId: ownerUserId,
            balanceLKR: balance,
            autoDeductEnabled: autoDeductEnabled
        )
    }

    func createWalletIfNeeded(userId: String) async throws {
        guard !userId.isEmpty,
              !userId.contains("/") else {
            throw WalletError.invalidUserId
        }

        let walletDocument = database
            .collection("wallets")
            .document(userId)

        _ = try await database.runTransaction { transaction, errorPointer in
            do {
                let document = try transaction.getDocument(walletDocument)

                guard !document.exists else {
                    return nil
                }

                transaction.setData(
                    [
                        "userId": userId,
                        "balanceLKR": 0,
                        "autoDeductEnabled": false
                    ],
                    forDocument: walletDocument
                )

                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    func addDemoFunds(userId: String) async throws {
        guard !userId.isEmpty, !userId.contains("/") else {
            throw WalletError.invalidUserId
        }

        let operationKey = "wallet.pendingDemoTopUp.\(userId)"
        let defaults = UserDefaults.standard
        let operationId = defaults.string(forKey: operationKey) ?? UUID().uuidString

        defaults.set(operationId, forKey: operationKey)

        let result = try await Functions.functions()
            .httpsCallable("topUpWallet")
            .call([
                "amountLKR": 1000,
                "operationId": operationId
            ])

        guard let data = result.data as? [String: Any],
              let returnedOperationId = data["operationId"] as? String,
              returnedOperationId == operationId,
              let balance = data["balanceLKR"] as? Int,
              balance >= 0 else {
            throw WalletError.invalidTopUpResponse
        }

        defaults.removeObject(forKey: operationKey)
    }

    func setTicketAutoDeduct(enabled: Bool) async throws {
        let result = try await Functions.functions()
            .httpsCallable("setTicketAutoDeduct")
            .call(["enabled": enabled])

        guard let data = result.data as? [String: Any],
              let savedEnabled = data["enabled"] as? Bool,
              savedEnabled == enabled else {
            throw WalletError.invalidAutoDeductResponse
        }
    }
}

private enum WalletError: LocalizedError {
    case invalidUserId
    case invalidDetails
    case invalidTopUpResponse
    case invalidAutoDeductResponse

    var errorDescription: String? {
        switch self {
        case .invalidUserId:
            return "Your user ID is missing or incorrect."
        case .invalidDetails:
            return "Your wallet details are missing or incorrect."
        case .invalidTopUpResponse:
            return "The top-up response could not be confirmed. Please try again."
        case .invalidAutoDeductResponse:
            return "The wallet setting could not be confirmed. Refresh and try again."
        }
    }
}
