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
            case .wardenRequest(let request):
                VStack(spacing: AppSpacing.medium) {
                    Text("Warden Application")
                        .font(AppTypography.titleMedium)
                    
                    Text(request.status.rawValue)
                        .font(AppTypography.bodyBold)
                    
                    Text(request.status.message)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Check Status") {
                        appState.loadUserProfile()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Sign Out") {
                        appState.signOut()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background.ignoresSafeArea())
            case .error(let message):
                errorView(message: message)
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
                SignInView(
                    title: "Staff sign in",
                    message: "Sign in with your Warden or Admin account.",
                    showWardenSignUp: true
                )
            }
        }
        .onDisappear {
            showSignIn = false
            showSignUp = false
            showStaffSignIn = false
        }
    }
    
    
    private func errorView(message: String) -> some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: AppSpacing.medium) {
                Text("Account Problem")
                    .font(AppTypography.titleMedium)
                
                Text(message)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Button("Try Again") {
                    appState.loadUserProfile()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Sign Out") {
                    appState.signOut()
                }
            }
            .padding()
        }
    }
    
    private func motoristHomeView(profile: UserProfile) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    Text("Welcome, \(profile.name)")
                        .font(AppTypography.titleMedium)

                    Text("Driver Dashboard")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    ActiveParkingCard(userId: profile.id)

                    NavigationLink {
                        MotoristParkingView()
                    } label: {
                        Text("Parking Zones")
                    }
                    .buttonStyle(.borderedProminent)

                    NavigationLink {
                        WalletView(profile: profile)
                    } label: {
                        Text("Wallet")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    NavigationLink {
                        ParkingHistoryView(profile: profile)
                    } label: {
                        Text("Parking History")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Sign Out") {
                        appState.signOut()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(AppSpacing.large)
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

                   NavigationLink {
                       ParkingZonesView()
                   } label: {
                       Text("Parking Zones")
                   }
                   .buttonStyle(.borderedProminent)

                   NavigationLink {
                       WardenAssignmentsView(adminUserId: profile.id)
                   } label: {
                       Text("Warden Assignments")
                   }
                   .buttonStyle(.borderedProminent)

                   NavigationLink {
                       WardenRequestsView(adminUserId: profile.id)
                   } label: {
                       Text("Warden Applications")
                   }
                   .buttonStyle(.borderedProminent)

                   Button("Sign Out") {
                       appState.signOut()
                   }
                   .buttonStyle(.borderedProminent)
               }
               .padding(AppSpacing.large)
           }
       }
}

private struct ActiveParkingCard: View {
    let userId: String

    @State private var session: ParkingSession?
    @State private var isLoading = true
    @State private var errorMessage = ""

    private let repository = ParkingSessionRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Current parking")
                .font(AppTypography.titleSmall)

            if isLoading {
                ProgressView("Checking your parking...")
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(AppColors.statusOverstay)
            } else if let session {
                Text(session.zoneName)
                    .font(AppTypography.bodyBold)

                Text(session.licensePlate)
                    .foregroundStyle(AppColors.textSecondary)

                TimelineView(.periodic(from: .now, by: 1)) { clock in
                    Text(remainingTime(
                        until: session.paidUntil,
                        now: clock.date
                    ))
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(
                        session.paidUntil > clock.date
                            ? AppColors.statusValid
                            : AppColors.statusOverstay
                    )
                }

                Text("Paid until \(formattedDate(session.paidUntil))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Text("Use Parking Zones to extend or end parking.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("You have no active parking.")
                    .foregroundStyle(AppColors.textSecondary)
            }

            Button("Refresh parking") {
                Task {
                    await loadSession()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(
                cornerRadius: AppSpacing.radiusCard
            )
        )
        .onAppear {
            Task {
                await loadSession()
            }
        }
    }

    @MainActor
    private func loadSession() async {
        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        do {
            session = try await repository.getActiveSession(userId: userId)
        } catch {
            session = nil
            errorMessage = "Could not load parking. Tap Refresh to try again."
        }
    }

    private func remainingTime(until paidUntil: Date, now: Date) -> String {
        let secondsLeft = Int(paidUntil.timeIntervalSince(now))

        if secondsLeft <= 0 {
            return "Paid time has ended"
        }

        let hours = secondsLeft / 3600
        let minutes = (secondsLeft % 3600) / 60
        let seconds = secondsLeft % 60

        if hours > 0 {
            return "\(hours) hr \(minutes) min remaining"
        }

        if minutes > 0 {
            return "\(minutes) min \(seconds) sec remaining"
        }

        return "\(seconds) sec remaining"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "Asia/Colombo")

        return formatter.string(from: date)
    }
}
