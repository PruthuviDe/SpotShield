//
//  SpotShieldApp.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-01.
//

import SwiftUI

@main
struct SpotShieldApp: App {
    @State private var appState: AppState

    init() {
        NotificationManager.shared.configure()
        FirebaseConfig.configure()
        _appState = State(initialValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .environment(appState)
        }
    }
}

