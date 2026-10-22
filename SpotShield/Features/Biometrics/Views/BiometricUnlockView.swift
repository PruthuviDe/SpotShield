//
//  BiometricUnlockView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI

struct BiometricUnlockView: View {
    let attemptID: Int

    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: BiometricUnlockViewModel
    @FocusState private var isPasswordFieldFocused: Bool

    init(profile: UserProfile, attemptID: Int) {
        self.attemptID = attemptID
        _viewModel = State(
            initialValue: BiometricUnlockViewModel(profile: profile)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    Spacer(minLength: 0)
                    AuthenticationHeaderView(
                        title: "Welcome back, \(viewModel.profile.name)",
                        message: unlockDescription
                    )

                    if !viewModel.errorMessage.isEmpty {
                        AppMessageView(
                            title: viewModel.errorMessage,
                            appearance: .error
                        )
                    }

                    if viewModel.isBiometricAvailable {
                        AppButton(
                            title: viewModel.isCheckingBiometrics
                                ? "Authenticating…"
                                : "Unlock with \(viewModel.biometricDeviceName)",
                            systemImage: viewModel.biometricIcon,
                            isLoading: viewModel.isCheckingBiometrics
                        ) {
                            Task { await viewModel.unlockWithBiometrics() }
                        }
                    }

                    if viewModel.isShowingPasswordField {
                        SecureField(
                            "Account password",
                            text: $viewModel.password,
                            prompt: Text("Enter your account password")
                        )
                        .textContentType(.password)
                        .accessibilityLabel("Account password")
                        .textFieldStyle(AppTextFieldStyle())
                        .focused($isPasswordFieldFocused)
                        .submitLabel(.go)
                        .onAppear {
                            isPasswordFieldFocused = true
                        }
                        .onSubmit {
                            Task { await unlockWithPassword() }
                        }

                        AppButton(
                            title: "Continue",
                            isLoading: viewModel.isCheckingPassword
                        ) {
                            Task { await unlockWithPassword() }
                        }
                    } else {
                        Button("Use account password") {
                            viewModel.showPasswordEntry()
                        }
                        .font(AppTypography.bodyBold)
                        .frame(minHeight: AppSpacing.minTouchTarget)
                    }

                    Button("Use another account") {
                        appState.signOut()
                    }
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(minHeight: AppSpacing.minTouchTarget)
                    .disabled(viewModel.isCheckingPassword || viewModel.isCheckingBiometrics)

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
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .task(id: attemptID) {
            if viewModel.isBiometricAvailable {
                await viewModel.unlockWithBiometrics()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                viewModel.clearPasswordEntry()
                isPasswordFieldFocused = false
            }
        }
    }

    private func unlockWithPassword() async {
        isPasswordFieldFocused = false
        await viewModel.unlockWithPassword(using: appState)
        if !viewModel.errorMessage.isEmpty {
            isPasswordFieldFocused = true
        }
    }

    private var unlockDescription: String {
        if viewModel.isBiometricAvailable {
            return "Unlock with \(viewModel.biometricDeviceName) or your account password."
        }

        return "Enter your account password to continue."
    }
}
