//
//  WardenApplicationStatusView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct WardenApplicationStatusView: View {
    @Environment(AppState.self) private var appState
    let request: WardenRequest

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                AuthenticationHeaderView(
                    title: "Application status",
                    message: request.status.message
                )

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        AppStatusBadge(title: request.status.rawValue, appearance: statusAppearance)

                        Text(request.name)
                            .font(AppTypography.bodyBold)

                        Text(request.email)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                AppButton(title: "Check Status", systemImage: "arrow.clockwise") {
                    appState.loadUserProfile()
                }

                AppButton(title: "Sign Out", appearance: .secondary) {
                    appState.signOut()
                }
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var statusAppearance: AppStatusAppearance {
        switch request.status {
        case .waiting: .warning
        case .approved: .success
        case .rejected: .error
        }
    }
}
