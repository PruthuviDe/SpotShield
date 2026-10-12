//
//  WardenSignUpView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-12.
//

import SwiftUI

struct WardenSignUpView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = WardenSignUpViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                header
                fields

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.statusOverstay)
                        .multilineTextAlignment(.center)
                }

                submitButton
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .foregroundStyle(AppColors.textPrimary)
        .tint(AppColors.textPrimary)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Warden Application")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: AppSpacing.medium) {
            Image("SpotShieldLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)

            Text("Apply as a Warden")
                .font(AppTypography.titleLarge)

            Text("Create a login and send your application. An Admin must approve it before you can use Warden features.")
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, AppSpacing.large)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Full name")
                .font(AppTypography.bodyBold)

            TextField("Enter your name", text: $viewModel.fullName)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .frame(minHeight: AppSpacing.minTouchTarget)

            Divider()

            Text("Email")
                .font(AppTypography.bodyBold)

            TextField("Enter your email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: AppSpacing.minTouchTarget)

            Divider()

            Text("Password")
                .font(AppTypography.bodyBold)

            SecureField("Create a password", text: $viewModel.password)
                .textContentType(.newPassword)
                .frame(minHeight: AppSpacing.minTouchTarget)

            Divider()

            Text("Confirm password")
                .font(AppTypography.bodyBold)

            SecureField(
                "Enter your password again",
                text: $viewModel.confirmPassword
            )
            .textContentType(.newPassword)
            .frame(minHeight: AppSpacing.minTouchTarget)
        }
        .font(AppTypography.bodyMedium)
        .textFieldStyle(.plain)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(
                cornerRadius: AppSpacing.radiusCard
            )
        )
        .disabled(viewModel.isLoading)
    }

    private var submitButton: some View {
        Button {
            Task {
                await viewModel.submitRequest(appState: appState)
            }
        } label: {
            HStack(spacing: AppSpacing.small) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppColors.accent)

                    Text("Sending application...")
                } else {
                    Text("Send Application")
                }
            }
            .font(AppTypography.bodyBold)
            .foregroundStyle(AppColors.accent)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppColors.buttonBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }
}
