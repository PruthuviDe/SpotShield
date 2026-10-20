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

    init(profile: UserProfile? = nil) {
        _viewModel = State(initialValue: DriverSetupViewModel(profile: profile))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(viewModel.profile == nil ? "Finish your Driver account" : "Add your vehicle")
                    .font(AppTypography.titleMedium)
                if viewModel.profile == nil {
                    TextField("Full name", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)
                }
                TextField("License plate", text: $viewModel.licensePlate)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Text("One vehicle per Driver. Spaces and hyphens do not create a different plate.")
                    .font(AppTypography.caption)
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage).foregroundStyle(AppColors.statusOverstay)
                }
                Button(viewModel.isSaving ? "Saving..." : "Save Setup") {
                    Task {
                        if await viewModel.save() { appState.loadUserProfile() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSaving)
                if viewModel.profile == nil {
                    Button("Sign Out") { appState.signOut() }
                }
            }
            .padding(AppSpacing.large)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Driver Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}
