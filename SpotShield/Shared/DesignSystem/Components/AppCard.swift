//
//  AppCard.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.medium)
            .background(
                AppColors.card,
                in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
            )
    }
}
