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
    @FocusState private var focusedField: Field?

    private enum Field { case name, email, password, confirmation, plate }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Spacer(minLength: 0)
                    AuthenticationHeaderView(
                        title: "Create your account",
                        message: "Your next parking session starts here."
                    )
                    AppCard {
                        fields
                    }

                    if !viewModel.errorMessage.isEmpty {
                        AppMessageView(title: viewModel.errorMessage, appearance: .error)
                    }

                    AppButton(title: viewModel.isLoading ? "Creating account…" : "Create Driver Account", isLoading: viewModel.isLoading) {
                        focusedField = nil
                        Task { await viewModel.createAccount(appState: appState) }
                    }
                    .disabled(viewModel.isLoading)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.small)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(AppColors.background.ignoresSafeArea())
        .foregroundStyle(AppColors.textPrimary)
        .tint(AppColors.textPrimary)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isLoading)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            AppSectionHeader(title: "Account details")

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("Full name").font(AppTypography.bodyBold)
                TextField(
                    "Full name",
                    text: $viewModel.fullName,
                    prompt: Text("Enter your name").foregroundStyle(AppColors.textSecondary)
                )
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Full name")
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("Email").font(AppTypography.bodyBold)
                TextField(
                    "Email",
                    text: $viewModel.email,
                    prompt: Text("Enter your email").foregroundStyle(AppColors.textSecondary)
                )
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Email")
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("Password").font(AppTypography.bodyBold)
                SecureField(
                    "Password",
                    text: $viewModel.password,
                    prompt: Text("Create a password").foregroundStyle(AppColors.textSecondary)
                )
                    .textContentType(.newPassword)
                    .accessibilityLabel("Password")
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmation }
                Text("Use at least 6 characters.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("Confirm password").font(AppTypography.bodyBold)
                SecureField(
                    "Confirm password",
                    text: $viewModel.confirmPassword,
                    prompt: Text("Re-enter your password").foregroundStyle(AppColors.textSecondary)
                )
                    .textContentType(.newPassword)
                    .accessibilityLabel("Confirm password")
                    .focused($focusedField, equals: .confirmation)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .plate }
            }

            Divider()
                .padding(.vertical, AppSpacing.xSmall)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("Vehicle").font(AppTypography.titleSmall)
                Text("License plate (optional)").font(AppTypography.bodyBold)
                TextField(
                    "License plate",
                    text: $viewModel.licensePlate,
                    prompt: Text("Example: CAB-1234").foregroundStyle(AppColors.textSecondary)
                )
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityLabel("License plate, optional")
                    .focused($focusedField, equals: .plate)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                Text("Add your plate now, or later from Park.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .textFieldStyle(AppTextFieldStyle())
        .disabled(viewModel.isLoading)
    }
}
