//
//  AppFeedbackViews.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct AppMessageView: View {
    let title: String
    var message: String? = nil
    var appearance: AppStatusAppearance = .neutral

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            Image(systemName: appearance.systemImage)
                .font(AppTypography.bodyBold)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text(title)
                    .font(AppTypography.bodyBold)

                if let message {
                    Text(message)
                        .font(AppTypography.bodySmall)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(appearance.foreground)
        .padding(AppSpacing.medium)
        .background(
            appearance.background,
            in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
        )
        .accessibilityElement(children: .combine)
    }
}

struct AppLoadingView: View {
    let title: String

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            ProgressView()
                .tint(AppColors.textPrimary)
                .accessibilityHidden(true)

            Text(title)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.large)
        .accessibilityElement(children: .combine)
    }
}

struct AppEmptyStateView: View {
    let title: String
    let message: String
    var systemImage = "tray"

    var body: some View {
        AppCard {
            VStack(spacing: AppSpacing.small) {
                Image(systemName: systemImage)
                    .font(AppTypography.titleMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityHidden(true)

                Text(title)
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)

                Text(message)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .padding(.vertical, AppSpacing.small)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }
}
