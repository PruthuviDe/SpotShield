//
//  WalletTransactionRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-18.
//

import Foundation
import FirebaseFirestore

final class WalletTransactionRepository {
    private lazy var database = Firestore.firestore()

    func getTransactions(userId: String) async throws -> [WalletTransaction] {
        guard !userId.isEmpty,
              !userId.contains("/") else {
            throw WalletTransactionError.invalidUserId
        }

        let result = try await database
            .collection("wallets")
            .document(userId)
            .collection("transactions")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments(source: .server)

        var transactions: [WalletTransaction] = []

        for document in result.documents {
            var data = document.data()
            data["id"] = document.documentID

            let transaction = try Firestore.Decoder().decode(
                WalletTransaction.self,
                from: data
            )

            guard transaction.userId == userId,
                  transaction.amountLKR > 0,
                  transaction.balanceAfterLKR >= 0,
                  !transaction.operationId.isEmpty else {
                throw WalletTransactionError.invalidDetails
            }

            transactions.append(transaction)
        }

        return transactions
    }
}

private enum WalletTransactionError: LocalizedError {
    case invalidUserId
    case invalidDetails

    var errorDescription: String? {
        switch self {
        case .invalidUserId:
            return "Your user ID is missing or incorrect."
        case .invalidDetails:
            return "A wallet transaction has missing or incorrect details."
        }
    }
}
