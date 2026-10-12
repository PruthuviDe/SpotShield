//
//  SignInView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-11.
//

import SwiftUI

struct SignInView: View {
    @State private var viewModel = SignInViewModel()
    var title = "Welcome back"
    var message = "Sign in to your SpotShield account."

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

                signInButton
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .foregroundStyle(AppColors.textPrimary)
        .tint(AppColors.textPrimary)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: AppSpacing.medium) {
            Image("SpotShieldLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)

            Text(title)
                .font(AppTypography.titleLarge)

            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, AppSpacing.large)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Email")
                .font(AppTypography.bodyBold)

            TextField("Enter your email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(AppSpacing.medium)
                .background(
                    AppColors.card,
                    in: RoundedRectangle(
                        cornerRadius: AppSpacing.radiusButton
                    )
                )

            Text("Password")
                .font(AppTypography.bodyBold)
                .padding(.top, AppSpacing.xSmall)

            SecureField("Enter your password", text: $viewModel.password)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit {
                    Task {
                        await viewModel.signIn()
                    }
                }
                .padding(AppSpacing.medium)
                .background(
                    AppColors.card,
                    in: RoundedRectangle(
                        cornerRadius: AppSpacing.radiusButton
                    )
                )
        }
        .font(AppTypography.bodyMedium)
        .disabled(viewModel.isLoading)
    }

    private var signInButton: some View {
        Button {
            Task {
                await viewModel.signIn()
            }
        } label: {
            HStack(spacing: AppSpacing.small) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppColors.accent)
                }

                Text(viewModel.isLoading ? "Signing in..." : "Sign In")
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

