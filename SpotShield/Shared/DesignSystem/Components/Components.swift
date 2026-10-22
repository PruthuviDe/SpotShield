//
//  Components.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

#if DEBUG
struct DesignSystemPreview: View {
    @State private var email = ""
    @State private var password = ""
    @State private var didContinue = false

    var body: some View {
        ScrollView {
            components
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.large)
        }
        .background(AppColors.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    var components: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AppSectionHeader(title: "Shared components", subtitle: "SpotShield design foundation")

            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    AppStatusBadge(title: "Active", appearance: .success)
                    Text("Galle Road Zone A")
                        .font(AppTypography.titleMedium)
                    Text("Paid until 14:30")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .foregroundStyle(AppColors.textPrimary)
            }

            VStack(spacing: AppSpacing.small) {
                AppButton(title: "Continue", systemImage: "arrow.right") {
                    didContinue = true
                }
                AppButton(title: "Refresh", systemImage: "arrow.clockwise", appearance: .secondary) {
                    didContinue = false
                }
                AppButton(title: "End Parking", appearance: .destructive) { }
                AppButton(title: "Saving…", isLoading: true) { }
                AppButton(title: "Continue") { }
                    .disabled(true)
            }

            if didContinue {
                AppMessageView(title: "Ready to continue", appearance: .success)
            }

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                AppSectionHeader(title: "Account details")
                Text("Email").font(AppTypography.bodyBold)
                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Email")
                Text("Password").font(AppTypography.bodyBold)
                SecureField("Enter your password", text: $password)
                    .textContentType(.password)
                    .accessibilityLabel("Password")
            }
            .foregroundStyle(AppColors.textPrimary)
            .textFieldStyle(AppTextFieldStyle())

            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.xSmall) { badges }
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) { badges }
            }

            AppMessageView(title: "Settings saved", appearance: .success)
            AppMessageView(title: "Parking expires soon", message: "Extend your parking if you need more time.", appearance: .warning)
            AppMessageView(title: "Unable to load parking", message: "Check your connection and try again.", appearance: .error)
            AppButton(title: "Try Again", appearance: .secondary) { }
            AppLoadingView(title: "Loading parking…")
            AppEmptyStateView(title: "No parking history", message: "Your completed sessions will appear here.", systemImage: "clock.arrow.circlepath")
        }
    }

    @ViewBuilder private var badges: some View {
        AppStatusBadge(title: "Pending")
        AppStatusBadge(title: "Expiring", appearance: .warning)
        AppStatusBadge(title: "Expired", appearance: .error)
    }
}

#Preview("Light") {
    DesignSystemPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    DesignSystemPreview().preferredColorScheme(.dark)
}

#Preview("Larger text") {
    DesignSystemPreview()
        .preferredColorScheme(.light)
        .dynamicTypeSize(.accessibility3)
}
#endif
