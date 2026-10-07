//
//  RootCoordinatorView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import SwiftUI

struct RootCoordinatorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                loadingView
            case .signedOut:
                signedOutView
            case .signedIn(let profile):
                switch profile.role {
                case .motorist:
                    motoristHomeView(profile: profile)
                case .warden:
                    wardenHomeView(profile: profile)
                case .admin:
                    adminHomeView(profile: profile)
                }
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: AppSpacing.small) {
                ProgressView()
                Text("Loading SpotShield...")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var signedOutView: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: AppSpacing.medium) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 64))
                        .foregroundStyle(AppColors.accent)

                    Text("SpotShield")
                        .font(AppTypography.titleLarge)

                    Text("Smart Parking & Enforcement")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func motoristHomeView(profile: UserProfile) -> some View {
        NavigationStack {
            VStack(spacing: AppSpacing.medium) {
                Text("Welcome, \(profile.name)")
                    .font(AppTypography.titleMedium)
                Text("Driver Dashboard")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Button("Sign Out") {
                    appState.signOut()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func wardenHomeView(profile: UserProfile) -> some View {
        NavigationStack {
            VStack(spacing: AppSpacing.medium) {
                Text("Welcome, \(profile.name)")
                    .font(AppTypography.titleMedium)
                Text("Parking Warden Dashboard")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Button("Sign Out") {
                    appState.signOut()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func adminHomeView(profile: UserProfile) -> some View {
        NavigationStack {
            VStack(spacing: AppSpacing.medium) {
                Text("Welcome, \(profile.name)")
                    .font(AppTypography.titleMedium)
                Text("Admin Dashboard")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Button("Sign Out") {
                    appState.signOut()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
