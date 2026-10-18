//
//  WalletTransaction.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-18.
//

import Foundation

struct WalletTransaction: Identifiable, Codable {
    var id: String
    var userId: String
    var type: WalletTransactionType
    var amountLKR: Int
    var balanceAfterLKR: Int
    var createdAt: Date
    var operationId: String
    var parkingSessionId: String? = nil
    var ticketId: String? = nil
}
