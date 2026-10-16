//
//  ParkingZoneDetailViewModel.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import Foundation
import Observation

@MainActor
@Observable
final class ParkingZoneDetailViewModel {
    var zone: ParkingZone

    init(zone: ParkingZone) {
        self.zone = zone
    }

    func openingStatus(at time: Date = Date()) -> String {
        guard zone.isPublished, zone.isActive else {
            return "Currently unavailable"
        }

        guard zone.openingHour >= 0,
              zone.openingHour <= 23,
              zone.closingHour > zone.openingHour,
              zone.closingHour <= 24,
              let timeZone = TimeZone(identifier: zone.timeZoneId) else {
            return "Opening hours unavailable"
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let currentHour = calendar.component(.hour, from: time)

        if currentHour >= zone.openingHour,
           currentHour < zone.closingHour {
            return "Open now"
        }

        return "Closed now"
    }
}
