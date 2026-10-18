//
//  FirebaseConfig.swift
//  SpotShield
//
//  Firebase client configuration and setup.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

enum FirebaseConfig {
    static func configure() {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["SPOTSHIELD_USE_EMULATORS"] == "1" {
            let options = FirebaseOptions(
                googleAppID: "1:1234567890:ios:0123456789abcdef",
                gcmSenderID: "1234567890"
            )
            options.apiKey = "demo-api-key"
            options.projectID = "demo-spotshield"

            FirebaseApp.configure(options: options)
            Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)

            let database = Firestore.firestore()
            let settings = database.settings
            settings.host = "127.0.0.1:8080"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            database.settings = settings
            return
        }
        #endif

        FirebaseApp.configure()
    }
}
