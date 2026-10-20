//
//  PlateScanner.swift
//  SpotShield
//
//  Created by Pruthuvi de Silva on 2026-10-20.
//

import SwiftUI
import UIKit
import VisionKit

struct PlateScanner: UIViewControllerRepresentable {
    let onTextSelected: (String) -> Void

    func makeUIViewController(
        context: Context
    ) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )

        scanner.delegate = context.coordinator
        try? scanner.startScanning()

        return scanner
    }

    func updateUIViewController(
        _ scanner: DataScannerViewController,
        context: Context
    ) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextSelected: onTextSelected)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onTextSelected: (String) -> Void

        init(onTextSelected: @escaping (String) -> Void) {
            self.onTextSelected = onTextSelected
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            guard case .text(let text) = item else { return }
            onTextSelected(text.transcript)
        }
    }
}
