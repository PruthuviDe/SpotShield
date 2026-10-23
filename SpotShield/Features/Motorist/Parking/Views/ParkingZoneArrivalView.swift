import SwiftUI

struct ParkingZoneArrivalView: View {
    let zoneId: String

    @State private var viewModel = MotoristParkingViewModel()

    private var zone: ParkingZone? {
        viewModel.zones.first { $0.id == zoneId }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                AppLoadingView(title: "Opening parking zone…")
            } else if let zone {
                ParkingZoneDetailView(zone: zone)
            } else if !viewModel.errorMessage.isEmpty {
                AppMessageView(
                    title: "Could not load this parking zone",
                    message: viewModel.errorMessage,
                    appearance: .error,
                    actionTitle: "Try Again",
                    action: { Task { await viewModel.loadZones() } }
                )
                .padding(AppSpacing.large)
            } else {
                AppEmptyStateView(
                    title: "Parking zone unavailable",
                    message: "This zone is no longer published. Browse the map for current parking options.",
                    systemImage: "mappin.slash"
                )
                .padding(AppSpacing.large)
            }
        }
        .task {
            await viewModel.loadZones()
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background.ignoresSafeArea())
    }
}
