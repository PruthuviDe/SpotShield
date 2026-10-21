//
//  ParkingActivityAttributes.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import ActivityKit
import Foundation

nonisolated struct ParkingActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var paidUntil: Date
    }

    var sessionId: String
    var zoneName: String
}
