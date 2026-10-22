//
//  AdminOverviewView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

struct AdminOverviewView: View {
    @State private var viewModel: AdminOverviewViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
        .refreshOnAppearAndForeground { await viewModel.loadOverview() }
        .refreshable {
            await viewModel.loadOverview()
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "At a glance")

            if viewModel.isLoading && viewModel.lastUpdated == nil {
                AppLoadingView(title: "Loading overview…")
            }

            if !viewModel.errorMessage.isEmpty {
                AppMessageView(
                    title: "Overview unavailable",
                    message: viewModel.errorMessage,
                    appearance: .error,
                    actionTitle: "Try Again",
                    action: { Task { await viewModel.loadOverview() } }
                )
            }

            if let lastUpdated = viewModel.lastUpdated {
                if viewModel.isLoading {
                    ProgressView("Updating overview…")
                        .font(AppTypography.bodySmall)
                }
                LazyVGrid(
                    columns: statisticColumns,
                    alignment: .leading,
                    spacing: AppSpacing.medium
                ) {
                    statisticCard(
                        title: "Active zones",
                        count: viewModel.activeZoneCount,
                        systemImage: "mappin.and.ellipse"
                    )

                    statisticCard(
                        title: "Applications to review",
                        count: viewModel.pendingApplicationCount,
                        systemImage: "person.badge.plus"
                    )

                    statisticCard(
                        title: "Observations to review",
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
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 46, height: 46)
                    .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                    .accessibilityHidden(true)

                Text(count, format: .number)
                    .font(AppTypography.titleLarge)
                    .monospacedDigit()

                Text(title)
                    .font(AppTypography.bodyBold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.xSmall)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
    }

    private var statisticColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        let columnCount = horizontalSizeClass == .regular ? 3 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: AppSpacing.medium),
            count: columnCount
        )
    }

    private var managementLinks: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "Administration")

            AppCard {
                VStack(spacing: 0) {
                    Button(action: onOpenZones) {
                        managementRow(
                            "Parking Zones",
                            detail: "Rates, hours and availability",
                            systemImage: "map"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    NavigationLink {
                        WardenAssignmentsView(adminUserId: viewModel.profile.id)
                    } label: {
                        managementRow(
                            "Warden Assignments",
                            detail: "Manage zone coverage",
                            systemImage: "person.2"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    NavigationLink {
                        WardenRequestsView(adminUserId: viewModel.profile.id)
                    } label: {
                        managementRow(
                            "Warden Applications",
                            detail: "Review requests for Warden access",
                            systemImage: "person.badge.plus"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Button(action: onOpenRecords) {
                        managementRow(
                            "Review Observations",
                            detail: "Review reports and ticket decisions",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func managementRow(
        _ title: String,
        detail: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 44, height: 44)
                .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
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
        .padding(.vertical, AppSpacing.medium)
        .contentShape(Rectangle())
    }
}
