//
//  WardenPlateScanning.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import AVFoundation
import SwiftUI
import VisionKit

struct WardenPlateScanning: View {
    let onPlateScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPreparingCamera = true
    @State private var scannerIsReady = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if scannerIsReady {
                PlateScanner { recognizedText in
                    let plate = recognizedText
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .uppercased()

                    guard !plate.isEmpty else { return }

                    onPlateScanned(plate)
                    dismiss()
                }
                .ignoresSafeArea(edges: .bottom)
            } else if isPreparingCamera {
                ProgressView("Preparing camera...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)

                    Text(errorMessage ?? "The camera is unavailable.")
                        .multilineTextAlignment(.center)

                    Text("Close this screen to enter the plate manually.")
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Scan License Plate")
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

        case .denied, .restricted:
            cameraAuthorized = false

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
        isPreparingCamera = false
    }
}
