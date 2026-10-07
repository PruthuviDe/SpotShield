//
//  ParkingZone.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation

struct ParkingZone: Identifiable, Codable {
    var id: String
    var name: String
    var hourlyRateLKR:Int
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var openingHour: Int
    var closingHour: Int
    var isActive: Bool
}

