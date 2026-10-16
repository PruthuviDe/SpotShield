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
            VStack(spacing: AppSpacing.large) {
                Text("Waiting applications")
                    .font(AppTypography.titleMedium)

                if viewModel.isLoading {
                    ProgressView("Please wait...")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.statusOverstay)
                        .multilineTextAlignment(.center)
                }

                if viewModel.requests.isEmpty
                    && !viewModel.isLoading
                    && viewModel.errorMessage.isEmpty {
                    Text("There are no applications waiting for review.")
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ForEach(viewModel.requests) { request in
                    requestCard(request: request)
                }

                Button("Refresh") {
                    Task {
                        await viewModel.loadRequests()
                    }
                }
                .frame(minHeight: AppSpacing.minTouchTarget)
                .disabled(viewModel.isLoading)
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 600)
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

            Button("Cancel", role: .cancel) {}
        } message: { request in
            Text("Approve to give \(request.name) Warden access, or reject this application.")
        }
    }

    private func requestCard(
        request: WardenRequest
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(request.name)
                .font(AppTypography.titleSmall)

            Text(request.email)
                .foregroundStyle(AppColors.textSecondary)

            HStack {
                Text("Applied:")

                Text(request.createdAt, style: .date)
            }
            .font(AppTypography.bodySmall)
            .foregroundStyle(AppColors.textSecondary)

            Button {
                selectedRequest = request
                showReview = true
            } label: {
                Text("Review Application")
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColors.accent)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: AppSpacing.minTouchTarget
                    )
                    .background(
                        AppColors.buttonBackground,
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            AppColors.card,
            in: RoundedRectangle(
                cornerRadius: AppSpacing.radiusCard
            )
        )
    }
}
