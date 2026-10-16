//
//  WardenAssignment.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import Foundation

struct WardenAssignment: Identifiable, Codable {
    var id: String
    var parkingZoneId: String
    var wardenUserId: String

    var assignedByUserId: String
    var assignedAt: Date

    var isActive: Bool
    var endedAt: Date? = nil
}
