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
        let activities = Activity<ParkingActivityAttributes>.activities

        if let activity = activities.first(where: {
            $0.attributes.sessionId == session.id
        }) {
            for otherActivity in activities where otherActivity.id != activity.id {
                await otherActivity.end(nil, dismissalPolicy: .immediate)
            }

            await activity.update(content(for: session))
            return
        }

        await end()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let attributes = ParkingActivityAttributes(
            sessionId: session.id,
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

    func end() async {
        for activity in Activity<ParkingActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func end(sessionId: String) async {
        for activity in Activity<ParkingActivityAttributes>.activities
            where activity.attributes.sessionId == sessionId {
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
