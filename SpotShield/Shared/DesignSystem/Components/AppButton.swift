//
//  AppButton.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

enum AppButtonAppearance {
    case primary
    case secondary
    case destructive

    var foreground: Color {
        switch self {
        case .primary: AppColors.accent
        case .secondary: AppColors.textPrimary
        case .destructive: AppColors.statusOverstay
        }
    }

    var background: Color {
        switch self {
        case .primary: AppColors.buttonBackground
        case .secondary: AppColors.card
        case .destructive: AppColors.statusOverstayBackground
        }
    }
}

struct AppButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var appearance: AppButtonAppearance = .primary
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyBold)
            .multilineTextAlignment(.center)
            .foregroundStyle(appearance.foreground)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(appearance.background, in: Capsule())
            .overlay {
                if appearance == .secondary {
                    Capsule().strokeBorder(AppColors.border, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
            .opacity(!isEnabled && !isLoading ? 0.5 : (configuration.isPressed ? 0.8 : 1))
    }
}

struct AppButton: View {
    let title: String
    var systemImage: String? = nil
    var appearance: AppButtonAppearance = .primary
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(role: appearance == .destructive ? .destructive : nil, action: action) {
            HStack(spacing: AppSpacing.small) {
                if isLoading {
                    ProgressView()
                        .tint(appearance.foreground)
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(AppButtonStyle(appearance: appearance, isLoading: isLoading))
        .disabled(isLoading)
        .accessibilityValue(isLoading ? "In progress" : "")
    }
}
