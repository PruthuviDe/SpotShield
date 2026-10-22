//
//  DriverSetupView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI

struct DriverSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: DriverSetupViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case name, plate }

    init(profile: UserProfile? = nil) {
        _viewModel = State(initialValue: DriverSetupViewModel(profile: profile))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                AuthenticationHeaderView(
                    title: viewModel.profile == nil ? "Finish your account" : "Add your vehicle",
                    message: "Keep your parking connected to the right vehicle."
                )
                fields

                if !viewModel.errorMessage.isEmpty {
                    AppMessageView(title: viewModel.errorMessage, appearance: .error)
                }

                AppButton(title: viewModel.isSaving ? "Saving…" : "Save Details", isLoading: viewModel.isSaving) {
                    focusedField = nil
                    Task {
                        if await viewModel.save() {
                            appState.loadUserProfile()
                        }
                    }
                }

                if viewModel.profile == nil {
                    AppButton(title: "Sign Out", appearance: .secondary) {
                        appState.signOut()
                    }
                    .disabled(viewModel.isSaving)
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
        .navigationTitle(viewModel.profile == nil ? "Account Setup" : "Add Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isSaving)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if viewModel.profile == nil {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text("Full name").font(AppTypography.bodyBold)
                    TextField(
                        "Full name",
                        text: $viewModel.name,
                        prompt: Text("Enter your name").foregroundStyle(AppColors.textSecondary)
                    )
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Full name")
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .plate }
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(viewModel.profile == nil ? "License plate (optional)" : "License plate")
                    .font(AppTypography.bodyBold)
                TextField(
                    "License plate",
                    text: $viewModel.licensePlate,
                    prompt: Text("Example: CAB-1234").foregroundStyle(AppColors.textSecondary)
                )
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityLabel(viewModel.profile == nil ? "License plate, optional" : "License plate")
                    .focused($focusedField, equals: .plate)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                Text(viewModel.profile == nil ? "Add your plate now, or later from Park." : "Use the plate displayed on your vehicle.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .textFieldStyle(AppTextFieldStyle())
        .disabled(viewModel.isSaving)
    }
}
