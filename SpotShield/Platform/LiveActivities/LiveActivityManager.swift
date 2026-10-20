//
//  LiveActivityManager.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    func start(for session: ParkingSession) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        await endExistingActivities()

        let attributes = ParkingActivityAttributes(
            zoneName: session.zoneName
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content(for: session),
                pushType: nil
            )
        } catch {
            print("Could not start parking Live Activity: \(error.localizedDescription)")
        }
    }

    func update(for session: ParkingSession) async {
        guard let activity = Activity<ParkingActivityAttributes>.activities.first else {
            return
        }

        await activity.update(content(for: session))
    }

    func end() async {
        await endExistingActivities()
    }

    private func endExistingActivities() async {
        for activity in Activity<ParkingActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func content(
        for session: ParkingSession
    ) -> ActivityContent<ParkingActivityAttributes.ContentState> {
        ActivityContent(
            state: ParkingActivityAttributes.ContentState(
                paidUntil: session.paidUntil
            ),
            staleDate: session.paidUntil
        )
    }
}
