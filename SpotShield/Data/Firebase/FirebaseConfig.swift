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
import FirebaseFunctions

enum FirebaseConfig {
    static func configure() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard

        if let emulatorSetting = environment["SPOTSHIELD_USE_EMULATORS"] {
            defaults.set(emulatorSetting == "1", forKey: "SPOTSHIELD_USE_EMULATORS")
        }

        if let host = environment["SPOTSHIELD_EMULATOR_HOST"], !host.isEmpty {
            defaults.set(host, forKey: "SPOTSHIELD_EMULATOR_HOST")
        }

        if defaults.bool(forKey: "SPOTSHIELD_USE_EMULATORS") {
            let options = FirebaseOptions(
                googleAppID: "1:1234567890:ios:0123456789abcdef",
                gcmSenderID: "1234567890"
            )
            options.apiKey = "demo-api-key"
            options.projectID = "demo-spotshield"

            #if targetEnvironment(simulator)
            let host = "127.0.0.1"
            #else
            let host = defaults.string(forKey: "SPOTSHIELD_EMULATOR_HOST") ?? "localhost"
            #endif

            FirebaseApp.configure(options: options)
            Auth.auth().useEmulator(withHost: host, port: 9099)

            let database = Firestore.firestore()
            let settings = database.settings
            settings.host = "\(host):8080"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            database.settings = settings

            let functions = Functions.functions()
            functions.useEmulator(withHost: host, port: 5001)

            return
        }
        #endif

        FirebaseApp.configure()
    }
}
