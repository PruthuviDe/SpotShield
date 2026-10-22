//
//  SignInView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-11.
//

import SwiftUI

struct SignInView: View {
    @State private var viewModel = SignInViewModel()
    @FocusState private var focusedField: Field?
    var title = "Welcome back"
    var message = "Sign in to your SpotShield account."
    var showWardenSignUp = false
    var navigationTitle = "Sign In"

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                AuthenticationHeaderView(title: title, message: message)
                fields
                forgotPasswordButton

                if !viewModel.errorMessage.isEmpty {
                    AppMessageView(title: viewModel.errorMessage, appearance: .error)
                }

                if !viewModel.successMessage.isEmpty {
                    AppMessageView(title: "Check your email", message: viewModel.successMessage, appearance: .success)
                }

                AppButton(title: viewModel.isLoading ? "Signing in…" : "Sign In", isLoading: viewModel.isLoading) {
                    focusedField = nil
                    Task { await viewModel.signIn() }
                }
                .disabled(viewModel.isBusy)

                if showWardenSignUp {
                    NavigationLink {
                        WardenSignUpView()
                    } label: {
                        Text("Apply as a Warden")
                    }
                    .buttonStyle(AppButtonStyle(appearance: .secondary))
                    .disabled(viewModel.isBusy)
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isLoading)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
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

            Text("Password")
                .font(AppTypography.bodyBold)
                .padding(.top, AppSpacing.xSmall)
            SecureField(
                "Password",
                text: $viewModel.password,
                prompt: Text("Enter your password").foregroundStyle(AppColors.textSecondary)
            )
                .textContentType(.password)
                .accessibilityLabel("Password")
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                    focusedField = nil
                    Task { await viewModel.signIn() }
                }
        }
        .textFieldStyle(AppTextFieldStyle())
        .disabled(viewModel.isBusy)
    }

    private var forgotPasswordButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.sendPasswordReset() }
        } label: {
            Text(viewModel.isSendingPasswordReset ? "Sending reset link…" : "Forgot Password?")
                .font(AppTypography.bodyBold)
                .padding(.vertical, AppSpacing.xSmall)
                .frame(minHeight: AppSpacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .disabled(viewModel.isBusy)
    }
}
