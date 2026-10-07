//
//  Wallet.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation

struct Wallet: Identifiable, Codable {
    var id: String
    var userId: String
    var balanceLKR: Int
    var autoDeductEnabled: Bool
}
