//
//  StaffAccessView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct StaffAccessView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                AuthenticationHeaderView(
                    title: "Staff sign in",
                    message: "Choose your role to continue."
                )

                NavigationLink {
                    SignInView(
                        title: "Warden sign in",
                        message: "Access your patrol and observation records.",
                        showWardenSignUp: true,
                        navigationTitle: "Warden Sign In"
                    )
                } label: {
                    Label("Warden Sign In", systemImage: "viewfinder")
                }
                .buttonStyle(AppButtonStyle())

                NavigationLink {
                    SignInView(
                        title: "Admin sign in",
                        message: "Manage zones, staff and observation reviews.",
                        navigationTitle: "Admin Sign In"
                    )
                } label: {
                    Label("Admin Sign In", systemImage: "square.grid.2x2")
                }
                .buttonStyle(AppButtonStyle(appearance: .secondary))
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Staff Access")
        .navigationBarTitleDisplayMode(.inline)
    }
}
