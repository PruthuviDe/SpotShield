//
//  WardenRequestsView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct WardenRequestsView: View {
    let adminUserId: String

    @State private var viewModel = WardenRequestsViewModel()
    @State private var selectedRequest: WardenRequest?
    @State private var showReview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(
                    title: "Applications",
                    subtitle: "Review requests for Warden access."
                )

                if !viewModel.errorMessage.isEmpty {
                    AppMessageView(
                        title: "Could not load applications",
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

                if viewModel.isLoading && viewModel.requests.isEmpty {
                    AppLoadingView(title: "Loading applications…")
                } else if viewModel.requests.isEmpty,
                          viewModel.errorMessage.isEmpty {
                    AppEmptyStateView(
                        title: "No applications waiting",
                        message: "New Warden applications will appear here for review.",
                        systemImage: "person.badge.plus"
                    )
                } else {
                    ForEach(viewModel.requests) { request in
                        requestCard(request: request)
                    }
                }

                AppButton(
                    title: "Refresh",
                    systemImage: "arrow.clockwise",
                    appearance: .secondary,
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.loadRequests() }
                }
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle("Warden Applications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRequests()
        }
        .refreshable {
            await viewModel.loadRequests()
        }
        .confirmationDialog(
            "Review application",
            isPresented: $showReview,
            titleVisibility: .visible,
            presenting: selectedRequest
        ) { request in
            Button("Approve Warden Access") {
                Task {
                    await viewModel.approveRequest(
                        request: request,
                        adminUserId: adminUserId
                    )
                }
            }

            Button("Reject Application", role: .destructive) {
                Task {
                    await viewModel.rejectRequest(
                        request: request,
                        adminUserId: adminUserId
                    )
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: { request in
            Text("Approve to give \(request.name) Warden access, or reject this application.")
        }
    }

    private func requestCard(request: WardenRequest) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .top) {
                    Text(request.name)
                        .font(AppTypography.titleSmall)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppStatusBadge(title: "Awaiting review", appearance: .warning)
                }

                Text(request.email)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                Label(
                    "Applied \(request.createdAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar"
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

                AppButton(
                    title: "Review Application",
                    systemImage: "person.badge.key"
                ) {
                    selectedRequest = request
                    showReview = true
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
}
