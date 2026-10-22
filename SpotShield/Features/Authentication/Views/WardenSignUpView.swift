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
    @FocusState private var focusedField: Field?

    private enum Field { case name, email, password, confirmation }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                AuthenticationHeaderView(
                    title: "Apply as a Warden",
                    message: "Submit your application to join the parking team."
                )
                fields

                Text("Warden access begins once your application is approved.")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                if !viewModel.errorMessage.isEmpty {
                    AppMessageView(title: viewModel.errorMessage, appearance: .error)
                }

                AppButton(title: viewModel.isLoading ? "Sending application…" : "Send Application", isLoading: viewModel.isLoading) {
                    focusedField = nil
                    Task { await viewModel.submitRequest(appState: appState) }
                }
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
        .navigationBarBackButtonHidden(viewModel.isLoading)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
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
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
        }
        .textFieldStyle(AppTextFieldStyle())
        .disabled(viewModel.isLoading)
    }
}
