//
//  Vehicle.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation

struct Vehicle : Identifiable , Codable {
    var id: String
    var ownerUserId: String
    var licensePlate: String
    var make: String
    var model: String
}
    
    
