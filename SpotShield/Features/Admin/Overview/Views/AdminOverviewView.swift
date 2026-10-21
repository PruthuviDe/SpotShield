//
//  AdminOverviewView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct AdminOverviewView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: AdminOverviewViewModel

    init(profile: UserProfile) {
        _viewModel = State(initialValue: AdminOverviewViewModel(profile: profile))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Welcome, \(viewModel.profile.name)")
                        .font(AppTypography.titleMedium)

                    Text("Manage parking zones, staffing and observation reviews.")
                        .foregroundStyle(AppColors.textSecondary)
                }

                overview
                managementLinks

                Button("Sign Out", role: .destructive) {
                    appState.signOut()
                }
                .buttonStyle(.bordered)
                .tint(AppColors.statusOverstay)
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Admin Overview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.loadOverview() }
                } label: {
                    Label("Refresh overview", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileView(profile: viewModel.profile)
                } label: {
                    Label("Profile & Settings", systemImage: "person.crop.circle")
                }
            }
        }
        .task {
            await viewModel.loadOverview()
        }
        .refreshable {
            await viewModel.loadOverview()
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("At a glance")
                .font(AppTypography.titleSmall)

            if viewModel.isLoading {
                ProgressView("Loading overview...")
            } else if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundStyle(AppColors.statusOverstay)

                Button("Try Again") {
                    Task { await viewModel.loadOverview() }
                }
                .buttonStyle(.bordered)
            } else if let lastUpdated = viewModel.lastUpdated {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: AppSpacing.medium)],
                    alignment: .leading,
                    spacing: AppSpacing.medium
                ) {
                    statisticCard(
                        title: "Active parking zones",
                        count: viewModel.activeZoneCount,
                        systemImage: "mappin.and.ellipse"
                    )

                    statisticCard(
                        title: "Waiting applications",
                        count: viewModel.pendingApplicationCount,
                        systemImage: "person.badge.plus"
                    )

                    statisticCard(
                        title: "Observations awaiting review",
                        count: viewModel.pendingObservationCount,
                        systemImage: "doc.text.magnifyingglass"
                    )
                }

                if viewModel.activeZoneCount == 0 {
                    Text("No parking zones are active. Open Parking Zones to manage publication and Warden coverage.")
                        .foregroundStyle(AppColors.textSecondary)
                }

                if viewModel.pendingApplicationCount == 0 && viewModel.pendingObservationCount == 0 {
                    Text("No applications or observations are awaiting review.")
                        .foregroundStyle(AppColors.statusValid)
                }

                Text("Updated \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func statisticCard(title: String, count: Int, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .font(AppTypography.titleSmall)
                .foregroundStyle(AppColors.statusValid)
                .accessibilityHidden(true)

            Text(count, format: .number)
                .font(AppTypography.timerDisplay)

            Text(title)
                .font(AppTypography.bodyBold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
        .accessibilityElement(children: .combine)
    }

    private var managementLinks: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Manage")
                .font(AppTypography.titleSmall)

            NavigationLink {
                ParkingZonesView()
            } label: {
                managementLabel("Parking Zones", detail: "Rates, hours and zone availability", systemImage: "map")
            }

            NavigationLink {
                WardenAssignmentsView(adminUserId: viewModel.profile.id)
            } label: {
                managementLabel("Warden Assignments", detail: "Assign Wardens and manage coverage", systemImage: "person.2")
            }

            NavigationLink {
                WardenRequestsView(adminUserId: viewModel.profile.id)
            } label: {
                managementLabel("Warden Applications", detail: "Approve or reject waiting applications", systemImage: "person.badge.plus")
            }

            NavigationLink {
                AdminTicketReviewView()
            } label: {
                managementLabel("Review Observations", detail: "Review cases and saved ticket decisions", systemImage: "doc.text")
            }
        }
        .buttonStyle(.plain)
    }

    private func managementLabel(_ title: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(AppTypography.titleSmall)
                .foregroundStyle(AppColors.statusValid)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text(title)
                    .font(AppTypography.bodyBold)

                Text(detail)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: AppSpacing.small)

            Image(systemName: "chevron.right")
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: AppSpacing.minTouchTarget, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
        .contentShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
    }
}
