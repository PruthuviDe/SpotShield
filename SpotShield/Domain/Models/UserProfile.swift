//
//  UserProfile.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import Foundation

struct UserProfile: Identifiable, Codable {
    var id: String
    var name: String
    var email: String
    var role:UserRole
    var primaryVehicleId: String?
}


