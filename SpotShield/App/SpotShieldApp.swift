//
//  SpotShieldApp.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-01.
//

import SwiftUI
import FirebaseAuth

@main
struct SpotShieldApp: App {
    @State private var appState: AppState

    init() {
        NotificationManager.shared.configure()
        FirebaseConfig.configure()
        LocationManager.shared.updateSignedInUser(Auth.auth().currentUser?.uid)
        _appState = State(initialValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .environment(appState)
        }
    }
}

