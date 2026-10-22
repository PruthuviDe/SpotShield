//
//  AuthenticationHeaderView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct AuthenticationHeaderView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Image("SpotShieldLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)

            Text(title)
                .font(AppTypography.titleLarge)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.medium)
    }
}
