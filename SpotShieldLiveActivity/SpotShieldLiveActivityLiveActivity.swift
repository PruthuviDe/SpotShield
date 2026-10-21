//
//  SpotShieldLiveActivityLiveActivity.swift
//  SpotShieldLiveActivity
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct SpotShieldLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ParkingActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                Text(context.attributes.zoneName)
                    .font(.headline)
                    .foregroundStyle(Color.black)

                HStack {
                    Text("Parking active")
                        .foregroundStyle(Color.gray)

                    Spacer()

                    countdown(until: context.state.paidUntil)
                        .font(.title2.bold())
                        .foregroundStyle(Color.black)
                }

                Text(
                    "Paid until \(context.state.paidUntil.formatted(date: .omitted, time: .shortened))"
                )
                .foregroundStyle(Color.gray)
            }
            .padding()
            .activityBackgroundTint(.white)
            .activitySystemActionForegroundColor(.black)
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
