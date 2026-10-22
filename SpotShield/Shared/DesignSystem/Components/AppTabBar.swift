//
//  AppTabBar.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-21.
//

import SwiftUI

enum AppTab: String, Identifiable {
    case park, wallet, history, profile
    case patrol, records, overview, zones

    var id: String { rawValue }

    var title: String {
        switch self {
        case .park: "Park"
        case .wallet: "Wallet"
        case .history: "History"
        case .profile: "Profile"
        case .patrol: "Patrol"
        case .records: "Records"
        case .overview: "Overview"
        case .zones: "Zones"
        }
    }

    var systemImage: String {
        switch self {
        case .park: "parkingsign"
        case .wallet: "wallet.bifold"
        case .history: "clock.arrow.circlepath"
        case .profile: "person.crop.circle"
        case .patrol: "viewfinder"
        case .records: "doc.text"
        case .overview: "square.grid.2x2"
        case .zones: "mappin.and.ellipse"
        }
    }

    static func tabs(for role: UserRole) -> [AppTab] {
        switch role {
        case .motorist: [.park, .wallet, .history, .profile]
        case .warden: [.patrol, .records, .profile]
        case .admin: [.overview, .zones, .records]
        }
    }
}

struct AppTabBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let tabs: [AppTab]
    @Binding var selection: AppTab

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                sectionMenu
            } else {
                HStack(alignment: .top, spacing: AppSpacing.xxSmall) {
                    ForEach(tabs) { tab in
                        Button {
                            selection = tab
                        } label: {
                            VStack(spacing: AppSpacing.xxSmall) {
                                Image(systemName: tab.systemImage)
                                    .font(AppTypography.bodyBold)
                                    .frame(width: 24, height: 24)
                                    .accessibilityHidden(true)

                                Text(tab.title)
                                    .font(AppTypography.captionBold)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .foregroundStyle(selection == tab ? AppColors.textOnAccent : AppColors.textLight)
                            .background(
                                selection == tab ? AppColors.accent : .clear,
                                in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
                        }
                        .accessibilityAddTraits(selection == tab ? .isSelected : [])
                        .accessibilityIdentifier("navigation.\(tab.rawValue)")
                    }
                }
                .padding(AppSpacing.xSmall)
            }
        }
        .buttonStyle(.plain)
        .background(
            AppColors.buttonBackground,
            in: RoundedRectangle(cornerRadius: AppSpacing.large)
        )
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.xSmall)
    }

    private var sectionMenu: some View {
        Menu {
            ForEach(tabs) { tab in
                Button {
                    selection = tab
                } label: {
                    Label(tab.title, systemImage: selection == tab ? "checkmark" : tab.systemImage)
                }
                .accessibilityIdentifier("navigation.\(tab.rawValue)")
            }
        } label: {
            HStack(spacing: AppSpacing.small) {
                Label(selection.title, systemImage: selection.systemImage)
                Spacer(minLength: AppSpacing.small)
                Image(systemName: "chevron.up.chevron.down")
                    .accessibilityHidden(true)
            }
            .font(AppTypography.bodyBold)
            .foregroundStyle(AppColors.accent)
            .padding(AppSpacing.medium)
            .frame(minHeight: 54)
        }
        .accessibilityLabel("Sections")
        .accessibilityValue(selection.title)
        .accessibilityHint("Choose a section")
    }
}
