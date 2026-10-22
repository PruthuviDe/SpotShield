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
            return "Your application is waiting for approval."

        case .approved:
            return "Your application has been approved."

        case .rejected:
            return "Your application was not approved. Contact your administrator for help."
        }
    }
}
