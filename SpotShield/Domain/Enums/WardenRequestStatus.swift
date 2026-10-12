//
//  WardenRequestStatus.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-12.
//

import Foundation

enum WardenRequestStatus: String, Codable, CaseIterable {
    case waiting = "Waiting"
    case approved = "Approved"
    case rejected = "Rejected"

    var message: String {
        switch self {
        case .waiting:
            return "Your request is waiting for Admin approval."

        case .approved:
            return "Your request has been approved."

        case .rejected:
            return "Your request was not approved."
        }
    }
}
