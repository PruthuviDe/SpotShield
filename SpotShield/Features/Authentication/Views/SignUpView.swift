//
//  SignUpView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-12.
//

import SwiftUI

struct SignUpView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SignUpViewModel()

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

                createAccountButton
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .foregroundStyle(AppColors.textPrimary)
        .tint(AppColors.textPrimary)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: AppSpacing.medium) {
            Image("SpotShieldLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)

            Text("Create your account")
                .font(AppTypography.titleLarge)

            Text("Register as a driver to start parking.")
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

            Divider()

            Text("License plate (optional)")
                .font(AppTypography.bodyBold)

            TextField("Example: CAB-1234", text: $viewModel.licensePlate)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
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

    private var createAccountButton: some View {
        Button {
            Task {
                await viewModel.createAccount(appState: appState)
            }
        } label: {
            HStack(spacing: AppSpacing.small) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppColors.accent)
                }

                Text(
                    viewModel.isLoading
                        ? "Creating account..."
                        : "Create Driver Account"
                )
                .font(AppTypography.bodyBold)
            }
            .foregroundStyle(AppColors.accent)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppColors.buttonBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }
}
