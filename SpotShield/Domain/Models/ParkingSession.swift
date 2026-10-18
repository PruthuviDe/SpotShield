//
//  ParkingSession.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation

struct ParkingSession: Identifiable, Codable {
    var id: String
    var userId: String
    var vehicleId: String
    var parkingZoneId: String
    var zoneName: String
    var licensePlate: String

    var startTime: Date
    var paidUntil: Date
    var endTime: Date?

    var durationMinutes: Int
    var hourlyRateLKR: Int
    var totalPaidLKR: Int
    var policyVersion: Int

    var isActive: Bool
    var operationId: String
}

