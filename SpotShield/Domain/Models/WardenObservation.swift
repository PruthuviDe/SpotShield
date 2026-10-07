//
//  WardenObservation.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation

enum ObservationStatus: String, Codable, CaseIterable {
    case awaitingReview = "Awaiting Review"
    case ticketIssued = "Ticket Issued"
    case dismissed = "Dismissed"
}

struct WardenObservation: Identifiable, Codable {
    var id: String
    var wardenUserId: String
    var parkingZoneId: String
    var zoneName: String
    var licensePlate: String
    var observedAt: Date
    var reviewStatus: ObservationStatus
    var notes: String?
}
    
