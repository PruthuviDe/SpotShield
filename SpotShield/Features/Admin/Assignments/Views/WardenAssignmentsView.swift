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
        Form {
            messagesSection
            newAssignmentSection
            assignmentsSection

            Section {
                Button("Refresh") {
                    Task {
                        await viewModel.loadData()
                    }
                }
            }
            .listRowBackground(AppColors.card)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .tint(AppColors.textPrimary)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .disabled(viewModel.isLoading)
        .navigationTitle("Warden Assignments")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isLoading)
        .task {
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
                    await viewModel.endAssignment(
                        assignment: assignment
                    )
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(
                "This will end the Warden's assignment for this zone. "
                + "The record will stay in history."
            )
        }
    }

    private var messagesSection: some View {
        Section {
            if viewModel.isLoading {
                ProgressView("Please wait...")
            }

            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundStyle(AppColors.statusOverstay)
            }

            if !viewModel.successMessage.isEmpty {
                Text(viewModel.successMessage)
                    .foregroundStyle(AppColors.statusValid)
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var newAssignmentSection: some View {
        Section {
            if !viewModel.isLoading,
               viewModel.errorMessage.isEmpty {
                if viewModel.zones.isEmpty {
                    Text("Create a parking zone first.")
                        .foregroundStyle(AppColors.textSecondary)
                }

                if viewModel.wardens.isEmpty {
                    Text("Approve a Warden application first.")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if !viewModel.zones.isEmpty,
               !viewModel.wardens.isEmpty {
                Picker(
                    "Parking zone",
                    selection: $viewModel.selectedZoneId
                ) {
                    Text("Choose a zone").tag("")

                    ForEach(viewModel.zones) { zone in
                        Text(zone.name).tag(zone.id)
                    }
                }

                Picker(
                    "Warden",
                    selection: $viewModel.selectedWardenId
                ) {
                    Text("Choose a Warden").tag("")

                    ForEach(viewModel.wardens) { warden in
                        Text(warden.name).tag(warden.id)
                    }
                }

                Button {
                    Task {
                        await viewModel.createAssignment(
                            adminUserId: adminUserId
                        )
                    }
                } label: {
                    Text("Assign Warden")
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            AppColors.buttonBackground,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("New assignment")
        } footer: {
            Text("Assigning a Warden does not publish the zone.")
        }
        .listRowBackground(AppColors.card)
    }

    private var assignmentsSection: some View {
        Section("Assignments") {
            if viewModel.assignments.isEmpty,
               !viewModel.isLoading,
               viewModel.errorMessage.isEmpty {
                Text("No assignments yet.")
                    .foregroundStyle(AppColors.textSecondary)
            }

            ForEach(viewModel.assignments) { assignment in
                assignmentRow(assignment: assignment)
            }
        }
        .listRowBackground(AppColors.card)
    }

    private func assignmentRow(
        assignment: WardenAssignment
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(zoneName(zoneId: assignment.parkingZoneId))
                .font(AppTypography.titleSmall)

            Text(wardenName(userId: assignment.wardenUserId))

            Text(assignment.isActive ? "Active" : "Ended")
                .font(AppTypography.captionBold)
                .foregroundStyle(
                    assignment.isActive
                        ? AppColors.statusValid
                        : AppColors.statusNeutral
                )

            Text(
                "Started: "
                + assignment.assignedAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary)

            if let endedAt = assignment.endedAt {
                Text(
                    "Ended: "
                    + endedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            }

            if assignment.isActive {
                Button("End Assignment", role: .destructive) {
                    selectedAssignment = assignment
                    showEndConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(AppColors.statusOverstay)
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    private func zoneName(zoneId: String) -> String {
        return viewModel.zones.first {
            $0.id == zoneId
        }?.name ?? zoneId
    }

    private func wardenName(userId: String) -> String {
        return viewModel.wardens.first {
            $0.id == userId
        }?.name ?? userId
    }
}
