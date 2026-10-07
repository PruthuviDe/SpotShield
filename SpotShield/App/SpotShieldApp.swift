//
//  SpotShieldApp.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-01.
//

import SwiftUI
import FirebaseCore

@main
struct SpotShieldApp: App {
    @State private var appState = AppState()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .environment(appState)
        }
    }
}

