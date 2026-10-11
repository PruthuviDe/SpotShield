//
//  WelcomeView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//
import SwiftUI

struct WelcomeView: View {
    var onSignIn: () -> Void = {}
    var onCreateAccount: () -> Void = {}
    var onStaffSignIn: () -> Void = {}

    var body: some View {
        GeometryReader { screen in
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    Spacer(minLength: AppSpacing.large)

                    header

                    Spacer(minLength: AppSpacing.xxLarge)

                    buttons
                }
                .padding(AppSpacing.large)
                .frame(maxWidth: 480)
                .frame(
                    maxWidth: .infinity,
                    minHeight: screen.size.height
                )
            }
        }
        .background {
            GeometryReader { screen in
                Image("WelcomeBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screen.size.width, height: screen.size.height)
                    .clipped()
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.medium) {
            Image("SpotShieldLogo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text("SpotShield")
                .font(AppTypography.titleLarge)

            Text("Smart Public Parking & Digital Enforcement")
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: AppSpacing.xSmall) {
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 8, height: 8)

                Text("Parking made simple")
                    .font(AppTypography.captionBold)
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.xSmall)
            .background(AppColors.accentBackground, in: Capsule())
        }
        .foregroundStyle(AppColors.textPrimary)
        .multilineTextAlignment(.center)
    }

    private var buttons: some View {
        VStack(spacing: AppSpacing.small) {
            Button(action: onSignIn) {
                HStack {
                    Text("Sign In")

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textOnAccent)
                        .frame(width: 38, height: 38)
                        .background(AppColors.accent, in: Circle())
                        .accessibilityHidden(true)
                }
                .foregroundStyle(AppColors.accent)
                .padding(.leading, AppSpacing.large)
                .padding(.trailing, AppSpacing.xSmall)
                .padding(.vertical, AppSpacing.xSmall)
                .frame(minHeight: 54)
                .background(AppColors.buttonBackground, in: Capsule())
                .contentShape(Capsule())
            }

            Button(action: onCreateAccount) {
                Text("Create Driver Account")
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(AppSpacing.small)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(AppColors.card, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppColors.border, lineWidth: 1)
                    }
                    .contentShape(Capsule())
            }

            Button(action: onStaffSignIn) {
                Text("Staff Sign In — Warden & Admin")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .underline()
                    .frame(
                        maxWidth: .infinity,
                        minHeight: AppSpacing.minTouchTarget
                    )
                    .contentShape(Rectangle())
            }
        }
        .font(AppTypography.bodyBold)
        .multilineTextAlignment(.center)
        .buttonStyle(.plain)
    }
}

#Preview("Light Mode") {
    WelcomeView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    WelcomeView()
        .preferredColorScheme(.dark)
}
