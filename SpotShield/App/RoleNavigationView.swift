//
//  RoleNavigationView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI
import UIKit

struct RoleNavigationView: View {
    let profile: UserProfile
    @Binding var parkingSessionId: String?
    @Binding var parkingZoneId: String?
    @State private var selectedTab: AppTab
    @State private var parkingPath: [String] = []
    @State private var isKeyboardVisible = false
    @State private var isShowingAdminProfile = false

    init(
        profile: UserProfile,
        parkingSessionId: Binding<String?>,
        parkingZoneId: Binding<String?>
    ) {
        self.profile = profile
        _parkingSessionId = parkingSessionId
        _parkingZoneId = parkingZoneId
        _selectedTab = State(initialValue: AppTab.tabs(for: profile.role)[0])
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch profile.role {
                case .motorist: motoristTabs
                case .warden: wardenTabs
                case .admin: adminTabs
                }
            }
            .tabViewStyle(.tabBarOnly)

            if !isKeyboardVisible {
                AppTabBar(tabs: AppTab.tabs(for: profile.role), selection: $selectedTab)
                    .background(AppColors.background)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onChange(of: parkingSessionId, initial: true) { _, sessionId in
            guard profile.role == .motorist, let sessionId else { return }
            selectedTab = .park
            parkingPath = [sessionId]
            parkingSessionId = nil
        }
        .onChange(of: parkingZoneId, initial: true) { _, zoneId in
            guard profile.role == .motorist, let zoneId else { return }
            selectedTab = .park
            parkingPath = ["arrival-zone:\(zoneId)"]
            parkingZoneId = nil
        }
        .sheet(isPresented: $isShowingAdminProfile) {
            NavigationStack {
                ProfileView(profile: profile)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                isShowingAdminProfile = false
                            }
                        }
                    }
            }
        }
    }

    private var motoristTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $parkingPath) {
                MotoristHomeView(profile: profile)
                    .navigationDestination(for: String.self) { destination in
                        if destination.hasPrefix("arrival-zone:") {
                            let zoneId = String(destination.dropFirst("arrival-zone:".count))
                            ParkingZoneArrivalView(zoneId: zoneId)
                                .id(destination)
                        } else {
                            ParkingSetupView(profile: profile, expectedSessionId: destination)
                                .id(destination)
                        }
                    }
            }
            .tabItem { Label("Park", systemImage: "parkingsign") }
            .tag(AppTab.park)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                WalletView(profile: profile)
            }
            .tabItem { Label("Wallet", systemImage: "wallet.bifold") }
            .tag(AppTab.wallet)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                ParkingHistoryView(profile: profile)
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.history)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                ProfileView(profile: profile, onOpenWallet: { selectedTab = .wallet })
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private var wardenTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WardenPatrolView()
            }
            .tabItem { Label("Patrol", systemImage: "viewfinder") }
            .tag(AppTab.patrol)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                WardenRecordsView()
            }
            .tabItem { Label("Records", systemImage: "doc.text") }
            .tag(AppTab.records)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                ProfileView(profile: profile)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private var adminTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                AdminOverviewView(
                    profile: profile,
                    onOpenZones: { selectedTab = .zones },
                    onOpenRecords: { selectedTab = .records }
                )
                .toolbar { adminProfileLink }
            }
            .tabItem { Label("Overview", systemImage: "square.grid.2x2") }
            .tag(AppTab.overview)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                ParkingZonesView()
                    .toolbar { adminProfileLink }
            }
            .tabItem { Label("Zones", systemImage: "mappin.and.ellipse") }
            .tag(AppTab.zones)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                AdminTicketReviewView()
                    .toolbar { adminProfileLink }
            }
            .tabItem { Label("Records", systemImage: "doc.text") }
            .tag(AppTab.records)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private var adminProfileLink: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isShowingAdminProfile = true
            } label: {
                Label("Profile & Settings", systemImage: "person.crop.circle")
            }
        }
    }
}
