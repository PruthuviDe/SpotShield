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

                AppButton(
                    title: "Refresh assignments",
                    systemImage: "arrow.clockwise",
                    appearance: .secondary,
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.loadData() }
                }
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
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
        .confirmationDialog(
            "End this assignment?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible,
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
                appearance: .error
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

                Text("An assignment does not publish or activate the zone.")
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
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                        Text(zoneName(zoneId: assignment.parkingZoneId))
                            .font(AppTypography.titleSmall)

                        Text(wardenName(userId: assignment.wardenUserId))
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    AppStatusBadge(
                        title: assignment.isActive ? "Active" : "Ended",
                        appearance: assignment.isActive ? .success : .neutral
                    )
                }

                Label(
                    "Started \(assignment.assignedAt.formatted(date: .abbreviated, time: .shortened))",
                    systemImage: "calendar"
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

                if let endedAt = assignment.endedAt {
                    Label(
                        "Ended \(endedAt.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "calendar.badge.clock"
                    )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                }

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

    private func zoneName(zoneId: String) -> String {
        viewModel.zones.first { $0.id == zoneId }?.name ?? zoneId
    }

    private func wardenName(userId: String) -> String {
        viewModel.wardens.first { $0.id == userId }?.name ?? userId
    }
}
