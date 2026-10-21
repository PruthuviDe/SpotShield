//
//  ParkingZoneMapView.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import MapKit
import SwiftUI

struct ParkingZoneMapView: View {
    let zones: [ParkingZone]

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedZoneID: String?
    @State private var selectedZone: ParkingZone?
    @StateObject private var locationManager = LocationManager()

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
            Text(locationManager.statusMessage(for: zones))
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 14)
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
            }
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
