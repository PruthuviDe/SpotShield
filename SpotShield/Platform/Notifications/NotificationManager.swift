//
//  NotificationManager.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    func configure() {
        center.delegate = self
    }

    func requestParkingReminderPermission() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true

        case .denied:
            return false

        case .notDetermined:
            do {
                return try await center.requestAuthorization(
                    options: [.alert, .sound]
                )
            } catch {
                return false
            }

        @unknown default:
            return false
        }
    }

    func scheduleParkingExpiryReminder(
        for session: ParkingSession
    ) async -> Bool {
        cancelParkingExpiryReminder(sessionId: session.id)

        guard await notificationsAreAllowed() else {
            return false
        }

        guard session.isActive,
              session.paidUntil > Date() else {
            return false
        }

        let now = Date()
        let fiveMinutesBeforeExpiry =
            session.paidUntil.addingTimeInterval(-5 * 60)

        let reminderDate: Date
        let message: String

        if fiveMinutesBeforeExpiry > now {
            reminderDate = fiveMinutesBeforeExpiry
            message =
                "\(session.licensePlate) in \(session.zoneName) expires in about 5 minutes."
        } else {
            reminderDate = session.paidUntil
            message =
                "Paid parking for \(session.licensePlate) in \(session.zoneName) has reached its end time."
        }

        let secondsUntilReminder = reminderDate.timeIntervalSinceNow

        guard secondsUntilReminder > 0 else {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "Parking expiry reminder"
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, secondsUntilReminder),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: reminderIdentifier(sessionId: session.id),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    func cancelParkingExpiryReminder(sessionId: String) {
        let identifier = reminderIdentifier(sessionId: sessionId)

        center.removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
        center.removeDeliveredNotifications(
            withIdentifiers: [identifier]
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func notificationsAreAllowed() async -> Bool {
        let settings = await center.notificationSettings()

        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

    private func reminderIdentifier(sessionId: String) -> String {
        "parking-expiry-\(sessionId)"
    }
}
