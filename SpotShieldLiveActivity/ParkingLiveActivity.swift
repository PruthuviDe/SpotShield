//
//  ParkingLiveActivity.swift
//  SpotShieldLiveActivity
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct ParkingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ParkingActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                Text(context.attributes.zoneName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack {
                    Text("Parking active")
                        .foregroundStyle(.secondary)

                    Spacer()

                    countdown(until: context.state.paidUntil)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }

                Text(
                    "Paid until \(context.state.paidUntil.formatted(date: .omitted, time: .shortened))"
                )
                .foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
            .activitySystemActionForegroundColor(Color(uiColor: .label))
            .widgetURL(
                URL(string: "spotshield://parking/\(context.attributes.sessionId)")
            )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "car.fill")
                }

                DynamicIslandExpandedRegion(.trailing) {
                    countdown(until: context.state.paidUntil)
                        .font(.caption)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.zoneName)

                        Text(
                            "Paid until \(context.state.paidUntil.formatted(date: .omitted, time: .shortened))"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "car.fill")
            } compactTrailing: {
                countdown(until: context.state.paidUntil)
                    .font(.caption2)
            } minimal: {
                Image(systemName: "car.fill")
            }
            .keylineTint(.green)
            .widgetURL(
                URL(string: "spotshield://parking/\(context.attributes.sessionId)")
            )
        }
    }

    @ViewBuilder
    private func countdown(until deadline: Date) -> some View {
        if deadline > .now {
            Text(timerInterval: .now...deadline, countsDown: true)
                .monospacedDigit()
        } else {
            Text("Expired")
        }
    }
}
