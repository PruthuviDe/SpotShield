//
//  WardenPlateScanning.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import AVFoundation
import SwiftUI
import UIKit
import VisionKit

struct WardenPlateScanning: View {
    let onPlateScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPreparingCamera = true
    @State private var scannerIsReady = false
    @State private var cameraAccessDenied = false
    @State private var errorMessage = ""

    var body: some View {
        Group {
            if scannerIsReady {
                ZStack(alignment: .top) {
                    PlateScanner { recognizedText in
                        let plate = recognizedText
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .uppercased()

                        guard !plate.isEmpty else { return }

                        onPlateScanned(plate)
                        dismiss()
                    } onError: { error in
                        showCameraMessage("The camera could not start. \(error)")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)

                    VStack {
                        AppMessageView(
                            title: "Choose the correct plate",
                            message: "Tap the detected plate. Review it and confirm it before checking.",
                            appearance: .neutral
                        )
                        Spacer()
                    }
                    .padding(AppSpacing.medium)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        AppSectionHeader(
                            title: "Scan a vehicle plate",
                            subtitle: "Keep the full plate in view, then tap the correct result."
                        )

                        if isPreparingCamera {
                            AppLoadingView(title: "Preparing camera…")
                        } else {
                            AppMessageView(
                                title: "Camera scanner unavailable",
                                message: errorMessage,
                                appearance: .warning
                            )

                            if cameraAccessDenied,
                               let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                AppButton(
                                    title: "Open Settings",
                                    systemImage: "gearshape",
                                    appearance: .secondary
                                ) {
                                    openURL(settingsURL)
                                }
                            }

                            Text("Close this screen to enter the plate manually.")
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(AppSpacing.large)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Scan Plate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .task {
            await prepareCamera()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, cameraAccessDenied else { return }
            isPreparingCamera = true
            Task { await prepareCamera() }
        }
    }

    @MainActor
    private func prepareCamera() async {
        guard DataScannerViewController.isSupported else {
            showCameraMessage("This device does not support live text scanning.")
            return
        }

        let cameraAuthorized: Bool

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            cameraAccessDenied = !cameraAuthorized
        case .denied, .restricted:
            cameraAuthorized = false
            cameraAccessDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied
        @unknown default:
            cameraAuthorized = false
        }

        guard cameraAuthorized else {
            showCameraMessage("Camera access is needed to scan a plate. You can allow it in Settings.")
            return
        }

        guard DataScannerViewController.isAvailable else {
            showCameraMessage("The camera scanner is currently unavailable.")
            return
        }

        scannerIsReady = true
        isPreparingCamera = false
    }

    private func showCameraMessage(_ message: String) {
        errorMessage = message
        scannerIsReady = false
        isPreparingCamera = false
    }
}
