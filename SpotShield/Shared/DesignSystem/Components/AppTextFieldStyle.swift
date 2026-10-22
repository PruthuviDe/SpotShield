//
//  AppTextFieldStyle.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct AppTextFieldStyle: TextFieldStyle {
    @Environment(\.isEnabled) private var isEnabled

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppColors.textPrimary)
            .tint(AppColors.textPrimary)
            .padding(AppSpacing.medium)
            .frame(minHeight: 54)
            .background(
                AppColors.card,
                in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.radiusButton)
                    .strokeBorder(AppColors.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .opacity(isEnabled ? 1 : 0.5)
    }
}
