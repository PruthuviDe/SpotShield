//
//  AppStatusBadge.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

enum AppStatusAppearance {
    case neutral
    case success
    case warning
    case error

    var foreground: Color {
        switch self {
        case .neutral: AppColors.statusNeutral
        case .success: AppColors.statusValid
        case .warning: AppColors.statusExpiring
        case .error: AppColors.statusOverstay
        }
    }

    var background: Color {
        switch self {
        case .neutral: AppColors.statusNeutralBackground
        case .success: AppColors.statusValidBackground
        case .warning: AppColors.statusExpiringBackground
        case .error: AppColors.statusOverstayBackground
        }
    }

    var systemImage: String {
        switch self {
        case .neutral: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "exclamationmark.circle"
        }
    }
}

struct AppStatusBadge: View {
    let title: String
    var appearance: AppStatusAppearance = .neutral

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxSmall) {
            Image(systemName: appearance.systemImage)
                .accessibilityHidden(true)

            Text(title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(AppTypography.captionBold)
        .foregroundStyle(appearance.foreground)
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.xSmall)
        .background(appearance.background, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
