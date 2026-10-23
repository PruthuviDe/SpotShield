//
//  RootCoordinatorView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-07.
//

import SwiftUI

struct RootCoordinatorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSignIn = false
    @State private var showSignUp = false
    @State private var showStaffSignIn = false
    @State private var activityParkingSessionId: String?
    @State private var parkingZoneIdToOpen: String?
    @State private var notificationManager = NotificationManager.shared
    @State private var biometricManager = BiometricManager.shared
    @State private var hasEnteredBackground = false
    @State private var biometricAttemptID = 0
    
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
                signedInView(profile: profile)
            case .wardenRequest(let request):
                WardenApplicationStatusView(request: request)
            case .error(let message):
                errorView(message: message)
            }
        }
        .onOpenURL(perform: handleActivityLink)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                if case .signedIn(let profile) = appState.authState {
                    biometricManager.lock(for: profile.id)
                }
                hasEnteredBackground = true
            } else if phase == .active, hasEnteredBackground {
                hasEnteredBackground = false
                biometricAttemptID += 1
            }
        }
        .onChange(of: notificationManager.parkingSessionToOpen, initial: true) { _, sessionId in
            guard let sessionId else {
                return
            }

            activityParkingSessionId = sessionId
            notificationManager.parkingSessionToOpen = nil
        }
        .onChange(of: notificationManager.parkingZoneToOpen, initial: true) { _, _ in
            openPendingZoneArrival()
        }
        .onChange(of: signedInProfileId, initial: true) { _, _ in
            openPendingZoneArrival()
        }
    }

    @ViewBuilder
    private func signedInView(profile: UserProfile) -> some View {
        if biometricManager.isEnabled(for: profile.id),
           biometricManager.unlockedUserID != profile.id {
            BiometricUnlockView(
                profile: profile,
                attemptID: biometricAttemptID
            )
        } else {
            RoleNavigationView(
                profile: profile,
                parkingSessionId: $activityParkingSessionId,
                parkingZoneId: $parkingZoneIdToOpen
            )
            .id(profile.id)
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

    private var signedInProfileId: String? {
        guard case .signedIn(let profile) = appState.authState else {
            return nil
        }
        return profile.id
    }

    private func openPendingZoneArrival() {
        guard let destination = notificationManager.parkingZoneToOpen,
              let profileId = signedInProfileId else {
            return
        }

        guard destination.userId == profileId,
              case .signedIn(let profile) = appState.authState,
              profile.role == .motorist else {
            notificationManager.parkingZoneToOpen = nil
            return
        }

        parkingZoneIdToOpen = destination.zoneId
        notificationManager.parkingZoneToOpen = nil
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
