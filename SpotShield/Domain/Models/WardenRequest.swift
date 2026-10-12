//
//  WardenRequest.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-12.
//

import Foundation

struct WardenRequest: Identifiable, Codable {
    var id: String
    var name: String
    var email: String
    var status: WardenRequestStatus
    var createdAt: Date

    var reviewedByUserId: String? = nil
    var reviewedAt: Date? = nil
}
