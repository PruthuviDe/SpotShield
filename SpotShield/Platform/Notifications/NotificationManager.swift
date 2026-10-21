//
//  NotificationManager.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    var parkingSessionToOpen: String?
    private(set) var isParkingReminderUnavailable = false

    private let center = UNUserNotificationCenter.current()
    private var signedInUserId: String?
    private var hasLoadedAccount = false
    private var reminderVersion = UUID()
    private var scheduledSessionId: String?

    private override init() {
        super.init()
    }

    func configure() {
        center.delegate = self
    }

    func updateSignedInUser(_ userId: String?) {
        guard !hasLoadedAccount || signedInUserId != userId else {
            return
        }

        hasLoadedAccount = true
        signedInUserId = userId
        isParkingReminderUnavailable = false
        scheduledSessionId = nil
        reminderVersion = UUID()
        let version = reminderVersion

        Task {
            await clearParkingReminders(keepingUserId: userId, version: version)
        }
    }

    func updateParkingExpiryReminder(
        for session: ParkingSession?,
        userId: String
    ) async -> Bool {
        guard signedInUserId == userId, !Task.isCancelled else {
            return false
        }

        if let session, session.userId != userId {
            return false
        }

        guard let session, session.isActive, session.paidUntil > Date() else {
            await cancelParkingExpiryReminders(userId: userId)
            return signedInUserId == userId && !Task.isCancelled
        }

        return await scheduleParkingExpiryReminder(for: session)
    }

    func requestParkingReminderPermission() async -> Bool {
        let userId = signedInUserId
        let settings = await center.notificationSettings()
        let allowed: Bool

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            allowed = true

        case .denied:
            allowed = false

        case .notDetermined:
            do {
                allowed = try await center.requestAuthorization(
                    options: [.alert, .sound]
                )
            } catch {
                allowed = false
            }

        @unknown default:
            allowed = false
        }

        if signedInUserId == userId {
            isParkingReminderUnavailable = !allowed
        }

        return allowed
    }

    func scheduleParkingExpiryReminder(
        for session: ParkingSession
    ) async -> Bool {
        guard signedInUserId == session.userId, !Task.isCancelled else {
            return false
        }

        reminderVersion = UUID()
        let version = reminderVersion
        scheduledSessionId = session.id
        await clearParkingReminders(version: version)

        guard isCurrentReminder(version: version, userId: session.userId) else {
            return false
        }

        let allowed = await notificationsAreAllowed()

        guard isCurrentReminder(version: version, userId: session.userId) else {
            return false
        }

        guard allowed else {
            isParkingReminderUnavailable = true
            return false
        }

        guard session.isActive,
              session.paidUntil > Date() else {
            isParkingReminderUnavailable = false
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
        content.userInfo = [
            "parkingSessionId": session.id,
            "userId": session.userId
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, secondsUntilReminder),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "parking-expiry-\(session.id)-\(version.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)

            guard isCurrentReminder(version: version, userId: session.userId) else {
                removeReminders(identifiers: [request.identifier])
                return false
            }

            isParkingReminderUnavailable = false
            return true
        } catch {
            if isCurrentReminder(version: version, userId: session.userId) {
                isParkingReminderUnavailable = true
            }
            return false
        }
    }

    func cancelParkingExpiryReminder(sessionId: String) async {
        if scheduledSessionId == sessionId {
            reminderVersion = UUID()
            scheduledSessionId = nil
            isParkingReminderUnavailable = false
        }

        await clearParkingReminders(sessionId: sessionId, version: reminderVersion)
    }

    private func cancelParkingExpiryReminders(userId: String) async {
        guard signedInUserId == userId else {
            return
        }

        reminderVersion = UUID()
        scheduledSessionId = nil
        isParkingReminderUnavailable = false
        await clearParkingReminders(version: reminderVersion)
    }

    private func clearParkingReminders(
        sessionId: String? = nil,
        keepingUserId: String? = nil,
        version: UUID
    ) async {
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()

        guard reminderVersion == version else {
            return
        }

        var identifiers: [String] = []

        for request in pending + delivered.map({ $0.request }) {
            guard request.identifier.hasPrefix("parking-expiry-") else {
                continue
            }

            if let keepingUserId,
               request.content.userInfo["userId"] as? String == keepingUserId {
                continue
            }

            if let sessionId,
               request.content.userInfo["parkingSessionId"] as? String != sessionId,
               request.identifier != "parking-expiry-\(sessionId)" {
                continue
            }

            identifiers.append(request.identifier)
        }

        removeReminders(identifiers: identifiers)
    }

    private func removeReminders(identifiers: [String]) {
        center.removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
        center.removeDeliveredNotifications(
            withIdentifiers: identifiers
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.identifier.hasPrefix("parking-expiry-") {
            guard let userId = notification.request.content.userInfo["userId"] as? String,
                  userId == signedInUserId else {
                return []
            }
        }

        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let request = response.notification.request

        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              request.identifier.hasPrefix("parking-expiry-"),
              let sessionId = request.content.userInfo["parkingSessionId"] as? String,
              !sessionId.isEmpty,
              let userId = request.content.userInfo["userId"] as? String,
              signedInUserId == nil || signedInUserId == userId else {
            return
        }

        parkingSessionToOpen = sessionId
    }

    private func notificationsAreAllowed() async -> Bool {
        let settings = await center.notificationSettings()

        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

    private func isCurrentReminder(version: UUID, userId: String) -> Bool {
        reminderVersion == version && signedInUserId == userId && !Task.isCancelled
    }
}
