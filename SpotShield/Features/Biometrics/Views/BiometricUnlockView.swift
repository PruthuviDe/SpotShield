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
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                Image(systemName: viewModel.biometricIcon)
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.accent)
                    .accessibilityHidden(true)

                Text("Unlock SpotShield")
                    .font(AppTypography.titleLarge)
                    .multilineTextAlignment(.center)

                Text(unlockDescription)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

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
                } else {
                    AppMessageView(
                        title: "Biometric unlock is unavailable. Continue with your account password.",
                        appearance: .neutral
                    )
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
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, minHeight: 420)
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
            return "Use \(viewModel.biometricDeviceName) or your account password to continue as \(viewModel.profile.name)."
        }

        return "Enter your account password to continue as \(viewModel.profile.name)."
    }
}
