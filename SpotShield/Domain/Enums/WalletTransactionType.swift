//
//  WalletTransactionType.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-18.
//

import Foundation

enum WalletTransactionType: String, Codable, CaseIterable {
    case topUp = "Top Up"
    case parkingPayment = "Parking Payment"
    case parkingExtension = "Parking Extension"
    case ticketPayment = "Ticket Payment"
}
