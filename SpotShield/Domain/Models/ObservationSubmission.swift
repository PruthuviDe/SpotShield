//
//  ObservationSubmission.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import Foundation

struct ObservationSubmission: Codable {
    var id: String
    var zoneId: String
    var licensePlate: String
    var notes: String
}
