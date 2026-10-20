//
//  PlateCheckResult.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation

struct PlateCheckResult {
    var status: ParkingStatus
    var parkingStatus: String
    var checkedAt: Date

    var hasValidParking: Bool {
        status == .valid || status == .expiring
    }
}

struct ObservationReview {
    var check: PlateCheckResult
    var canIssueTicket: Bool
    var issueBlockedReason: String
    var recipientKnown: Bool
}
