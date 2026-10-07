//
//  SimulatedTicket.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation

struct SimulatedTicket: Identifiable, Codable {
    var id: String
    var observationId: String
    var userId: String
    var parkingZoneId: String
    var zoneName: String
    var licensePlate: String
    var fineAmountLKR: Int
    var issuedAt: Date
    var issuedByAdminUserId: String
    var reason: String
    var paymentStatus: TicketStatus
}
