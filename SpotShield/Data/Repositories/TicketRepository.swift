//
//  TicketRepository.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation
import FirebaseFunctions

final class TicketRepository {
    func getMyTickets() async throws -> [SimulatedTicket] {
        let result = try await Functions.functions().httpsCallable("getMyTickets").call()
        guard let data = result.data as? [String: Any],
              let rows = data["tickets"] as? [[String: Any]] else {
            throw NSError(domain: "Tickets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load your tickets."])
        }
        return try rows.map { row in
            guard let id = row["id"] as? String,
                  let observationId = row["observationId"] as? String,
                  let userId = row["userId"] as? String,
                  let zoneId = row["parkingZoneId"] as? String,
                  let zoneName = row["zoneName"] as? String,
                  let plate = row["licensePlate"] as? String,
                  let amount = row["fineAmountLKR"] as? Int,
                  let millis = row["issuedAtMillis"] as? NSNumber,
                  let adminId = row["issuedByAdminUserId"] as? String,
                  let reason = row["reason"] as? String,
                  let statusText = row["paymentStatus"] as? String,
                  let status = TicketStatus(rawValue: statusText) else {
                throw NSError(domain: "Tickets", code: 1, userInfo: [NSLocalizedDescriptionKey: "A ticket has missing details. Please refresh."])
            }
            return SimulatedTicket(
                id: id, observationId: observationId, userId: userId,
                parkingZoneId: zoneId, zoneName: zoneName, licensePlate: plate,
                fineAmountLKR: amount, issuedAt: Date(timeIntervalSince1970: millis.doubleValue / 1000),
                issuedByAdminUserId: adminId, reason: reason, paymentStatus: status
            )
        }
    }
}
