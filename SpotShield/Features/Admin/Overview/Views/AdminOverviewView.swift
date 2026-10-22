//
//  AdminOverviewView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct AdminOverviewView: View {
    @State private var viewModel: AdminOverviewViewModel
    let onOpenZones: () -> Void
    let onOpenRecords: () -> Void

    init(
        profile: UserProfile,
        onOpenZones: @escaping () -> Void,
        onOpenRecords: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: AdminOverviewViewModel(profile: profile))
        self.onOpenZones = onOpenZones
        self.onOpenRecords = onOpenRecords
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                AppSectionHeader(
                    title: "Welcome, \(viewModel.profile.name)",
                    subtitle: "Manage zones, Warden coverage and parking reviews."
                )

                overview
                managementLinks
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 920, alignment: .leading)
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
            AppSectionHeader(title: "At a glance")

            if viewModel.isLoading {
                AppLoadingView(title: "Loading overview…")
            } else if !viewModel.errorMessage.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    AppMessageView(
                        title: "Overview unavailable",
                        message: viewModel.errorMessage,
                        appearance: .error
                    )

                    AppButton(
                        title: "Try Again",
                        systemImage: "arrow.clockwise",
                        appearance: .secondary
                    ) {
                        Task { await viewModel.loadOverview() }
                    }
                }
            } else if let lastUpdated = viewModel.lastUpdated {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 230), spacing: AppSpacing.medium)],
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
                    AppMessageView(
                        title: "No active parking zones",
                        message: "Open Parking Zones to review publication and Warden coverage."
                    )
                }

                if viewModel.pendingApplicationCount == 0
                    && viewModel.pendingObservationCount == 0 {
                    AppMessageView(
                        title: "Reviews are up to date",
                        message: "There are no applications or observations waiting for review.",
                        appearance: .success
                    )
                }

                Text("Updated \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func statisticCard(
        title: String,
        count: Int,
        systemImage: String
    ) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                Image(systemName: systemImage)
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(AppColors.statusValid)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(count, format: .number)
                        .font(AppTypography.titleLarge)
                        .monospacedDigit()

                    Text(title)
                        .font(AppTypography.bodyBold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: AppSpacing.minTouchTarget, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
    }

    private var managementLinks: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "Administration")

            Button(action: onOpenZones) {
                managementLabel(
                    "Parking Zones",
                    detail: "Rates, hours and zone availability",
                    systemImage: "map"
                )
            }

            NavigationLink {
                WardenAssignmentsView(adminUserId: viewModel.profile.id)
            } label: {
                managementLabel(
                    "Warden Assignments",
                    detail: "Assign Wardens and manage zone coverage",
                    systemImage: "person.2"
                )
            }

            NavigationLink {
                WardenRequestsView(adminUserId: viewModel.profile.id)
            } label: {
                managementLabel(
                    "Warden Applications",
                    detail: "Review applications awaiting a decision",
                    systemImage: "person.badge.plus"
                )
            }

            Button(action: onOpenRecords) {
                managementLabel(
                    "Review Observations",
                    detail: "Review Warden reports and ticket decisions",
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func managementLabel(
        _ title: String,
        detail: String,
        systemImage: String
    ) -> some View {
        AppCard {
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
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(AppTypography.captionBold)
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: AppSpacing.minTouchTarget, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
        }
    }
}
