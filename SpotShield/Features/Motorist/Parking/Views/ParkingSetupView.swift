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
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    if let name = viewModel.activeSession?.zoneName ?? zone?.name {
                        Text(name).font(AppTypography.titleMedium).accessibilityAddTraits(.isHeader)
                    }
                    if viewModel.isLoading || viewModel.isLoadingSession {
                        AppLoadingView(title: "Checking your parking details…")
                    }
                    feedback.id("parking-feedback")
                    if let session = viewModel.activeSession {
                        activeSessionDetails(session)
                    } else if let zone, let vehicle = viewModel.vehicle,
                              !viewModel.isLoadingSession, viewModel.sessionErrorMessage.isEmpty {
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
                    AppButton(title: "Refresh Details", systemImage: "arrow.clockwise", appearance: .secondary) {
                        Task { await loadScreen() }
                    }
                    .disabled(viewModel.isBusy)
                }
                .padding(AppSpacing.large)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppColors.textPrimary)
            .background(AppColors.background.ignoresSafeArea())
            .tint(AppColors.textPrimary)
            .navigationTitle(zone == nil ? "Manage Parking" : "Parking Setup")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadScreen() }
            .onChange(of: viewModel.parkingErrorMessage) { _, message in
                if !message.isEmpty { scroll.scrollTo("parking-feedback", anchor: .top) }
            }
            .onChange(of: viewModel.successMessage) { _, message in
                if !message.isEmpty { scroll.scrollTo("parking-feedback", anchor: .top) }
            }
            .confirmationDialog("End parking?", isPresented: $isShowingEndConfirmation, titleVisibility: .visible) {
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
            } message: {
                Text("Unused parking time will not be refunded.")
            }
        }
    }

    private var feedback: some View {
        VStack(spacing: AppSpacing.medium) {
            if !viewModel.errorMessage.isEmpty {
                AppMessageView(title: viewModel.errorMessage, appearance: .error)
            }
            if !viewModel.sessionErrorMessage.isEmpty {
                AppMessageView(title: viewModel.sessionErrorMessage, appearance: .error)
            }
            if !viewModel.parkingErrorMessage.isEmpty {
                AppMessageView(title: viewModel.parkingErrorMessage, appearance: .error)
            }
            if !viewModel.notificationMessage.isEmpty {
                AppMessageView(title: "Parking reminder unavailable", message: viewModel.notificationMessage, appearance: .warning)
            }
            if !viewModel.successMessage.isEmpty {
                AppMessageView(title: viewModel.successMessage, appearance: .success)
            }
        }
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
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            let durations = viewModel.availableDurations(zone: zone, at: clock.date)
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    AppSectionHeader(title: "Choose parking time")
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
                    if let price = viewModel.estimatedPrice(zone: zone, at: clock.date) {
                        Divider()
                        AppSectionHeader(title: "Review your parking")
                        reviewDetail("Duration", value: "\(viewModel.selectedMinutes) minutes")
                        reviewDetail("Expected paid until", value: formattedDate(clock.date.addingTimeInterval(TimeInterval(viewModel.selectedMinutes * 60))))
                        walletBalance(price: price)
                        reviewDetail("Parking total", value: "LKR \(price.formatted())")
                        Text("Parking is paid from your wallet. Unused time is not refundable.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Toggle("I am parked in this zone", isOn: $viewModel.isParkedHere)
                            .tint(AppColors.statusValid)
                        AppButton(title: viewModel.isStartingParking ? "Starting…" : "Start Parking · LKR \(price.formatted())", isLoading: viewModel.isStartingParking) {
                            Task { await viewModel.startParking(zone: zone) }
                        }
                        .disabled(!viewModel.canStartParking(zone: zone, at: clock.date) || insufficientFunds(for: price))
                    }
                }
                .disabled(viewModel.isBusy)
            }
            .onChange(of: durations) { _, newDurations in
                if !viewModel.isBusy, !newDurations.contains(viewModel.selectedMinutes) {
                    viewModel.selectedMinutes = 0
                    viewModel.isParkedHere = false
                }
            }
        }
    }

    private func activeSessionDetails(_ session: ParkingSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        AppSectionHeader(
                            title: "Parking receipt",
                            subtitle: "Started \(formattedDate(session.startTime))"
                        )
                        AppStatusBadge(title: session.paidUntil > clock.date ? "Parking active" : "Paid time expired", appearance: session.paidUntil > clock.date ? .success : .error)
                        if session.paidUntil > clock.date {
                            Text(timerInterval: clock.date...session.paidUntil, countsDown: true)
                                .font(AppTypography.timerDisplay)
                                .accessibilityLabel("Parking time remaining")
                        }
                        reviewDetail("Parking zone", value: session.zoneName)
                        Label(session.licensePlate, systemImage: "car").font(AppTypography.bodyBold)
                        reviewDetail("Paid until", value: formattedDate(session.paidUntil))
                        reviewDetail("Total paid", value: "LKR \(session.totalPaidLKR.formatted())")
                    }
                }
                extensionDetails(at: clock.date)
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
                        reviewDetail("New paid until", value: formattedDate(session.paidUntil.addingTimeInterval(TimeInterval(viewModel.selectedExtensionMinutes * 60))))
                        walletBalance(price: price)
                        reviewDetail("Extension total", value: "LKR \(price.formatted())")
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
                AppMessageView(title: viewModel.walletErrorMessage, appearance: .warning)
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
