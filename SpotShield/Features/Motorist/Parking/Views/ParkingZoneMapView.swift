//
//  ParkingZoneMapView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import MapKit
import SwiftUI
import UIKit

struct ParkingZoneMapView: View {
    let zones: [ParkingZone]
    let userId: String

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedZoneID: String?
    @State private var selectedZone: ParkingZone?
    @StateObject private var locationManager = LocationManager.shared

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedZoneID) {
            UserAnnotation()

            ForEach(zones) { zone in
                MapCircle(
                    center: CLLocationCoordinate2D(
                        latitude: zone.latitude,
                        longitude: zone.longitude
                    ),
                    radius: zone.radiusMeters
                )
                .foregroundStyle(
                    circleColor(for: zone)
                        .opacity(circleOpacity(for: zone))
                )
                .stroke(
                    circleColor(for: zone),
                    lineWidth: selectedZoneID == zone.id ? 3 : 1
                )

                Marker(
                    zone.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: zone.latitude,
                        longitude: zone.longitude
                    )
                )
                .tint(
                    zone.isActive
                        ? AppColors.accent
                        : AppColors.textSecondary
                )
                .tag(zone.id)
            }
        }
        .overlay(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(locationManager.statusMessage(for: zones))
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        await locationManager.setArrivalAlertsEnabled(
                            for: zones,
                            userId: userId
                        )
                    }
                } label: {
                    Label(
                        locationManager.hasArrivalAlertsOptIn
                            ? "Turn Off Arrival Alerts"
                            : "Enable Arrival Alerts",
                        systemImage: locationManager.hasArrivalAlertsOptIn
                            ? "location.slash"
                            : "location"
                    )
                    .font(AppTypography.captionBold)
                }
                .foregroundStyle(AppColors.accent)
                .disabled(locationManager.isRequestingArrivalAlerts)

                if !locationManager.arrivalAlertsMessage.isEmpty {
                    Text(locationManager.arrivalAlertsMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if locationManager.shouldOpenSettingsForArrivalAlerts {
                    Button("Open Settings") {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        UIApplication.shared.open(settingsURL)
                    }
                    .font(AppTypography.captionBold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.medium)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
            )
            .padding()
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
        .onAppear {
            locationManager.requestLocationAccess()
            locationManager.updateMonitoredZones(zones, userId: userId)
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
        }
        .onChange(of: selectedZoneID) { _, zoneID in
            guard let zoneID else {
                selectedZone = nil
                return
            }

            selectedZone = zones.first { $0.id == zoneID }
        }
        .sheet(
            item: $selectedZone,
            onDismiss: {
                selectedZoneID = nil
            }
        ) { zone in
            NavigationStack {
                ParkingZoneDetailView(zone: zone)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { selectedZone = nil }
                        }
                    }
            }
            .tint(AppColors.textPrimary)
        }
        .navigationTitle("Parking Map")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func circleColor(for zone: ParkingZone) -> Color {
        if selectedZoneID == zone.id || zone.isActive {
            return AppColors.accent
        }

        return AppColors.textSecondary
    }

    private func circleOpacity(for zone: ParkingZone) -> Double {
        if selectedZoneID == zone.id {
            return 0.24
        }

        return zone.isActive ? 0.10 : 0.05
    }
}
