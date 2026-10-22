//
//  RootCoordinatorView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import SwiftUI

struct RootCoordinatorView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignIn = false
    @State private var showSignUp = false
    @State private var showStaffSignIn = false
    @State private var activityParkingSessionId: String?
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                loadingView
            case .signedOut:
                signedOutView
            case .needsProfile:
                NavigationStack { DriverSetupView() }
            case .signedIn(let profile):
                RoleNavigationView(
                    profile: profile,
                    parkingSessionId: $activityParkingSessionId
                )
                .id(profile.id)
            case .wardenRequest(let request):
                WardenApplicationStatusView(request: request)
            case .error(let message):
                errorView(message: message)
            }
        }
        .onOpenURL(perform: handleActivityLink)
        .onChange(of: notificationManager.parkingSessionToOpen, initial: true) { _, sessionId in
            guard let sessionId else {
                return
            }

            activityParkingSessionId = sessionId
            notificationManager.parkingSessionToOpen = nil
        }
    }

    private func handleActivityLink(_ url: URL) {
        guard url.scheme == "spotshield",
              url.host == "parking",
              let sessionId = url.pathComponents.dropFirst().first,
              !sessionId.isEmpty else {
            return
        }

        activityParkingSessionId = sessionId
    }
    
    private var loadingView: some View {
        AppLoadingView(title: "Loading your account…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background.ignoresSafeArea())
    }

    private var signedOutView: some View {
        NavigationStack {
            WelcomeView(
                onSignIn: {
                    showSignIn = true
                },
                onCreateAccount: {
                    showSignUp = true
                },
                onStaffSignIn: {
                    showStaffSignIn = true
                }
            )
            .navigationDestination(isPresented: $showSignIn) {
                SignInView()
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .navigationDestination(isPresented: $showStaffSignIn) {
                StaffAccessView()
            }
        }
        .onDisappear {
            showSignIn = false
            showSignUp = false
            showStaffSignIn = false
        }
    }
    
    
    private func errorView(message: String) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                AuthenticationHeaderView(
                    title: "Account access",
                    message: "We couldn't open your account."
                )
                AppMessageView(title: message, appearance: .error)
                AppButton(title: "Try Again", systemImage: "arrow.clockwise") {
                    appState.loadUserProfile()
                }
                AppButton(title: "Sign Out", appearance: .secondary) {
                    appState.signOut()
                }
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
    }
}
