//
//  ParkingSetupView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-16.
//

import SwiftUI

struct ParkingSetupView: View {
    let zone: ParkingZone?
    private let profile: UserProfile
    @State private var viewModel: ParkingSetupViewModel
    @State private var isShowingEndConfirmation = false
    @State private var sessionToEndId = ""
    @State private var actionFeedbackTitle = ""
    @State private var actionFeedbackMessage = ""
    @State private var isShowingActionFeedback = false

    init(zone: ParkingZone, profile: UserProfile) {
        self.zone = zone
        self.profile = profile
        _viewModel = State(initialValue: ParkingSetupViewModel(profile: profile))
    }

    init(profile: UserProfile, expectedSessionId: String? = nil) {
        self.zone = nil
        self.profile = profile
        _viewModel = State(initialValue: ParkingSetupViewModel(profile: profile, expectedSessionId: expectedSessionId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    if let name = viewModel.activeSession?.zoneName ?? zone?.name {
                        Text(name).font(AppTypography.titleMedium).accessibilityAddTraits(.isHeader)
                    }
                    if (viewModel.isLoading || viewModel.isLoadingSession)
                        && viewModel.activeSession == nil {
                        AppLoadingView(title: "Checking your parking details…")
                    }
                    feedback
                    if let session = viewModel.activeSession {
                        activeSessionDetails(session)
                    } else if let zone, let vehicle = viewModel.vehicle {
                        vehicleDetails(vehicle)
                        parkingDetails(zone)
                    } else if zone == nil, !viewModel.isLoadingSession, viewModel.sessionErrorMessage.isEmpty {
                        AppEmptyStateView(title: "No active parking", message: "Your completed sessions are available in History.", systemImage: "parkingsign.circle")
                    }
                    if profile.primaryVehicleId == nil, zone != nil {
                        NavigationLink {
                            DriverSetupView(profile: profile)
                        } label: {
                            Label("Add Vehicle", systemImage: "car")
                        }
                        .buttonStyle(AppButtonStyle())
                    }
                }
                .padding(AppSpacing.large)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            startParkingActionBar
        }
        .font(AppTypography.bodyMedium)
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.textPrimary)
        .navigationTitle(zone == nil ? "Manage Parking" : "Parking Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadScreen() }
                } label: {
                    Label("Refresh parking details", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isBusy)
            }
        }
        .task { await loadScreen() }
        .refreshable { await loadScreen() }
        .onChange(of: viewModel.parkingErrorMessage) { _, message in
            showActionFeedback(message, title: "Parking issue")
        }
        .onChange(of: viewModel.sessionErrorMessage) { _, message in
            guard viewModel.activeSession != nil else { return }
            showActionFeedback(message, title: "Could not refresh parking")
        }
        .onChange(of: viewModel.successMessage) { _, message in
            showActionFeedback(message, title: "Parking updated")
        }
        .alert(
            isShowingEndConfirmation ? "End parking?" : actionFeedbackTitle,
            isPresented: Binding(
                get: { isShowingEndConfirmation || isShowingActionFeedback },
                set: { isPresented in
                    if !isPresented {
                        isShowingEndConfirmation = false
                        isShowingActionFeedback = false
                    }
                }
            )
        ) {
            if isShowingEndConfirmation {
                Button("End Parking", role: .destructive) {
                    Task {
                        guard viewModel.activeSession?.id == sessionToEndId else {
                            viewModel.parkingErrorMessage = "Your parking session changed. Refresh and check it before ending."
                            return
                        }
                        await viewModel.endParking()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            if isShowingEndConfirmation {
                Text("Unused parking time will not be refunded.")
            } else {
                Text(actionFeedbackMessage)
            }
        }
    }

    private var feedback: some View {
        VStack(spacing: AppSpacing.medium) {
            if !viewModel.errorMessage.isEmpty {
                AppMessageView(
                    title: viewModel.errorMessage,
                    appearance: .error,
                    actionTitle: "Try Again",
                    action: { Task { await viewModel.loadVehicle() } }
                )
            }
            if !viewModel.sessionErrorMessage.isEmpty,
               viewModel.activeSession == nil {
                AppMessageView(title: viewModel.sessionErrorMessage, appearance: .error)
            }
            if !viewModel.notificationMessage.isEmpty {
                AppMessageView(title: "Parking reminder unavailable", message: viewModel.notificationMessage, appearance: .warning)
            }
        }
    }

    private func showActionFeedback(_ message: String, title: String) {
        guard !message.isEmpty else { return }
        actionFeedbackTitle = title
        actionFeedbackMessage = message
        isShowingActionFeedback = true
    }

    private func loadScreen() async {
        viewModel.successMessage = ""
        viewModel.parkingErrorMessage = ""
        if zone == nil {
            await viewModel.loadActiveSession()
            await viewModel.loadWalletBalance()
        } else {
            await viewModel.refresh()
        }
    }

    private func vehicleDetails(_ vehicle: Vehicle) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                AppSectionHeader(title: "Your vehicle")
                Label(vehicle.licensePlate, systemImage: "car").font(AppTypography.titleMedium)
                Text("Check the plate before starting parking.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func parkingDetails(_ zone: ParkingZone) -> some View {
        let currentTime = Date()
        let durations = viewModel.availableDurations(zone: zone, at: currentTime)
        return AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: "Choose parking time")
                HStack {
                    Label("Hourly rate", systemImage: "clock")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer(minLength: AppSpacing.small)
                    Text("LKR \(zone.hourlyRateLKR.formatted())")
                        .font(AppTypography.bodyBold)
                }
                if durations.isEmpty {
                    AppMessageView(title: "No parking time available", message: "The zone is closed or too close to closing time.", appearance: .warning)
                } else {
                    Picker("Parking duration", selection: $viewModel.selectedMinutes) {
                        Text("Choose a duration").tag(0)
                        ForEach(durations, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .background(AppColors.background, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                }
                if let price = viewModel.estimatedPrice(zone: zone, at: currentTime) {
                    Divider()
                    AppSectionHeader(title: "Review your parking")
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        reviewDetail("Duration", value: "\(viewModel.selectedMinutes) minutes")
                        reviewDetail("Expected paid until", value: formattedDate(currentTime.addingTimeInterval(TimeInterval(viewModel.selectedMinutes * 60))))
                    }
                    .padding(AppSpacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.background, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Parking total")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColors.textLight)
                            Spacer(minLength: AppSpacing.small)
                            Text("LKR \(price.formatted())")
                                .font(AppTypography.priceDisplay)
                                .foregroundStyle(AppColors.accent)
                                .fixedSize()
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text("Parking total")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColors.textLight)
                            Text("LKR \(price.formatted())")
                                .font(AppTypography.priceDisplay)
                                .foregroundStyle(AppColors.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(AppSpacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                    walletBalance(price: price)
                    Text("Parking is paid from your wallet. Unused time is not refundable.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Toggle("I am parked in this zone", isOn: $viewModel.isParkedHere)
                        .tint(AppColors.statusValid)
                }
            }
            .disabled(viewModel.isBusy)
        }
    }

    @ViewBuilder
    private var startParkingActionBar: some View {
        if let zone,
           viewModel.activeSession == nil,
           viewModel.vehicle != nil {
            let price = viewModel.estimatedPrice(zone: zone)
            let title = price.map { "Start Parking · LKR \($0.formatted())" } ?? "Start Parking"
            AppButton(
                title: viewModel.isStartingParking ? "Starting…" : title,
                isLoading: viewModel.isStartingParking
            ) {
                Task { await viewModel.startParking(zone: zone) }
            }
            .disabled(!viewModel.canStartParking(zone: zone) || insufficientFunds(for: price ?? 0))
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.small)
            .padding(.bottom, AppSpacing.small)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .background(AppColors.background)
        }
    }

    private func activeSessionDetails(_ session: ParkingSession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    AppSectionHeader(
                        title: "Parking receipt",
                        subtitle: "Started \(formattedDate(session.startTime))"
                    )
                    TimelineView(.periodic(from: .now, by: 1)) { clock in
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            AppStatusBadge(title: session.paidUntil > clock.date ? "Parking active" : "Paid time expired", appearance: session.paidUntil > clock.date ? .success : .error)
                            if session.paidUntil > clock.date {
                                Text(timerInterval: clock.date...session.paidUntil, countsDown: true)
                                    .font(AppTypography.timerDisplay)
                                    .accessibilityLabel("Parking time remaining")
                            }
                        }
                        .padding(AppSpacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(session.paidUntil > clock.date ? AppColors.accentBackground : AppColors.statusOverstayBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                    }
                    reviewDetail("Parking zone", value: session.zoneName)
                    Label(session.licensePlate, systemImage: "car")
                        .font(AppTypography.bodyBold)
                    reviewDetail("Paid until", value: formattedDate(session.paidUntil))
                    reviewDetail("Total paid", value: "LKR \(session.totalPaidLKR.formatted())")
                }
            }
            TimelineView(.periodic(from: .now, by: 60)) { clock in
                extensionDetails(at: clock.date)
            }
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text("Unused parking time is not refundable.")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                    AppButton(title: viewModel.isEndingParking ? "Ending…" : "End Parking", appearance: .destructive, isLoading: viewModel.isEndingParking) {
                        sessionToEndId = session.id
                        isShowingEndConfirmation = true
                    }
                    .disabled(viewModel.isBusy)
                }
            }
        }
    }

    private func extensionDetails(at time: Date) -> some View {
        let durations = viewModel.extensionDurations(at: time)
        return AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: "Extend parking")
                if durations.isEmpty {
                    Text("No extra time is available within this session's limits.")
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Picker("Extra parking time", selection: $viewModel.selectedExtensionMinutes) {
                        Text("Choose extra time").tag(0)
                        ForEach(durations, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .background(AppColors.background, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                    if let price = viewModel.extensionPrice(at: time), let session = viewModel.activeSession {
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            reviewDetail("New paid until", value: formattedDate(session.paidUntil.addingTimeInterval(TimeInterval(viewModel.selectedExtensionMinutes * 60))))
                        }
                        .padding(AppSpacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.background, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Extension total")
                                    .font(AppTypography.bodyBold)
                                    .foregroundStyle(AppColors.textLight)
                                Spacer(minLength: AppSpacing.small)
                                Text("LKR \(price.formatted())")
                                    .font(AppTypography.priceDisplay)
                                    .foregroundStyle(AppColors.accent)
                                    .fixedSize()
                            }
                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text("Extension total")
                                    .font(AppTypography.bodyBold)
                                    .foregroundStyle(AppColors.textLight)
                                Text("LKR \(price.formatted())")
                                    .font(AppTypography.priceDisplay)
                                    .foregroundStyle(AppColors.accent)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(AppSpacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.buttonBackground, in: RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
                        walletBalance(price: price)
                        Text("Extra time starts from your current paid-until time. Unused time is not refundable.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        AppButton(title: viewModel.isExtendingParking ? "Extending…" : "Extend Parking · LKR \(price.formatted())", isLoading: viewModel.isExtendingParking) {
                            Task { await viewModel.extendParking() }
                        }
                        .disabled(!viewModel.canExtendParking(at: time) || insufficientFunds(for: price))
                    }
                }
            }
            .disabled(viewModel.isBusy)
        }
        .onChange(of: durations) { _, newDurations in
            if !viewModel.isBusy, !newDurations.contains(viewModel.selectedExtensionMinutes) {
                viewModel.selectedExtensionMinutes = 0
            }
        }
    }

    private func walletBalance(price: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if viewModel.isLoadingWallet {
                AppLoadingView(title: "Checking wallet balance…")
            } else if let balance = viewModel.walletBalanceLKR {
                reviewDetail("Available balance", value: "LKR \(balance.formatted())")
                if balance < price {
                    AppMessageView(title: "Add funds to continue", message: "You need LKR \((price - balance).formatted()) more.", appearance: .warning)
                }
            } else if !viewModel.walletErrorMessage.isEmpty {
                AppMessageView(
                    title: viewModel.walletErrorMessage,
                    appearance: .warning,
                    actionTitle: "Try Again",
                    action: { Task { await viewModel.loadWalletBalance() } }
                )
            }
            NavigationLink {
                WalletView(profile: profile)
            } label: {
                Label("Open Wallet", systemImage: "wallet.bifold")
            }
            .buttonStyle(AppButtonStyle(appearance: .secondary))
            Text("Balance and availability are checked when payment is confirmed.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func insufficientFunds(for price: Int) -> Bool {
        if let balance = viewModel.walletBalanceLKR { return balance < price }
        return false
    }

    private func reviewDetail(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                Text(title).foregroundStyle(AppColors.textSecondary).fixedSize()
                Spacer(minLength: AppSpacing.small)
                Text(value).font(AppTypography.bodyBold).fixedSize()
            }
            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text(title).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Text(value).font(AppTypography.bodyBold).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "Asia/Colombo")
        return formatter.string(from: date)
    }
}
