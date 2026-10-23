//
//  WardenAssignmentsView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct WardenAssignmentsView: View {
    let adminUserId: String

    @State private var viewModel = WardenAssignmentsViewModel()
    @State private var selectedAssignment: WardenAssignment?
    @State private var showEndConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(
                    title: "Warden coverage",
                    subtitle: "Assign Wardens to zones and manage current coverage."
                )

                feedback
                newAssignmentSection
                assignmentsSection
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Warden Assignments")
        .navigationBarTitleDisplayMode(.inline)
        .refreshOnAppearAndForeground { await viewModel.loadData() }
        .refreshable {
            await viewModel.loadData()
        }
        .alert(
            "End this assignment?",
            isPresented: $showEndConfirmation,
            presenting: selectedAssignment
        ) { assignment in
            Button("End Assignment", role: .destructive) {
                Task {
                    await viewModel.endAssignment(assignment: assignment)
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("This will end the Warden's assignment for this zone. The history will be kept.")
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if viewModel.isLoading
            && viewModel.zones.isEmpty
            && viewModel.wardens.isEmpty
            && viewModel.assignments.isEmpty {
            AppLoadingView(title: "Loading assignments…")
        }

        if !viewModel.errorMessage.isEmpty {
            AppMessageView(
                title: "Could not update Warden coverage",
                message: viewModel.errorMessage,
                appearance: .error,
                actionTitle: "Try Again",
                action: { Task { await viewModel.loadData() } }
            )
        }

        if !viewModel.successMessage.isEmpty {
            AppMessageView(
                title: viewModel.successMessage,
                appearance: .success
            )
        }
    }

    private var newAssignmentSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(
                    title: "New assignment",
                    subtitle: "Choose a zone and a Warden."
                )

                if viewModel.zones.isEmpty && !viewModel.isLoading {
                    AppMessageView(
                        title: "No parking zones available",
                        message: "Create a parking zone before assigning coverage."
                    )
                }

                if viewModel.wardens.isEmpty && !viewModel.isLoading {
                    AppMessageView(
                        title: "No Wardens available",
                        message: "Approve a Warden application before creating an assignment."
                    )
                }

                if !viewModel.zones.isEmpty && !viewModel.wardens.isEmpty {
                    Picker("Parking zone", selection: $viewModel.selectedZoneId) {
                        Text("Choose a zone").tag("")

                        ForEach(viewModel.zones) { zone in
                            Text(zone.name).tag(zone.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, AppSpacing.xSmall)

                    Picker("Warden", selection: $viewModel.selectedWardenId) {
                        Text("Choose a Warden").tag("")

                        ForEach(viewModel.wardens) { warden in
                            Text(warden.name).tag(warden.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, AppSpacing.xSmall)

                    AppButton(
                        title: "Assign Warden",
                        systemImage: "person.badge.plus",
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            await viewModel.createAssignment(
                                adminUserId: adminUserId
                            )
                        }
                    }
                    .disabled(
                        viewModel.isLoading
                            || viewModel.selectedZoneId.isEmpty
                            || viewModel.selectedWardenId.isEmpty
                    )
                }

                Text("Assigning a Warden to an active zone updates its current coverage. Inactive zones must be activated separately.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: "Assignments")

            if viewModel.assignments.isEmpty,
               !viewModel.isLoading,
               viewModel.errorMessage.isEmpty {
                AppEmptyStateView(
                    title: "No assignments yet",
                    message: "Current and ended Warden coverage will appear here.",
                    systemImage: "person.2"
                )
            } else {
                ForEach(viewModel.assignments) { assignment in
                    assignmentCard(assignment: assignment)
                }
            }
        }
    }

    private func assignmentCard(assignment: WardenAssignment) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                        Text(zoneName(zoneId: assignment.parkingZoneId))
                            .font(AppTypography.titleMedium)
                            .fixedSize(horizontal: false, vertical: true)

                        Label(wardenName(userId: assignment.wardenUserId), systemImage: "person")
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    AppStatusBadge(
                        title: assignment.isActive ? "Active" : "Ended",
                        appearance: assignment.isActive ? .success : .neutral
                    )
                }

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    assignmentDate("Assigned", date: assignment.assignedAt)
                    if let endedAt = assignment.endedAt {
                        assignmentDate("Ended", date: endedAt)
                    }
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.background, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))

                if assignment.isActive {
                    AppButton(
                        title: "End Assignment",
                        systemImage: "person.badge.minus",
                        appearance: .destructive
                    ) {
                        selectedAssignment = assignment
                        showEndConfirmation = true
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    private func assignmentDate(_ title: String, date: Date) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer(minLength: AppSpacing.small)
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.bodySmall.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.bodySmall.weight(.semibold))
            }
        }
    }

    private func zoneName(zoneId: String) -> String {
        viewModel.zones.first { $0.id == zoneId }?.name ?? zoneId
    }

    private func wardenName(userId: String) -> String {
        viewModel.wardens.first { $0.id == userId }?.name ?? userId
    }
}
