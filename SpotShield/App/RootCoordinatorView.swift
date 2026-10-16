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
