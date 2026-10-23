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
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        ScannerViewController(onTextSelected: onTextSelected, onError: onError)
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {
    }

    final class ScannerViewController: UIViewController, DataScannerViewControllerDelegate {
        private let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        private let onTextSelected: (String) -> Void
        private let onError: (String) -> Void
        private var recognizedTextItems: [UUID: RecognizedItem.Text] = [:]

        init(
            onTextSelected: @escaping (String) -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onTextSelected = onTextSelected
            self.onError = onError
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            scanner.delegate = self
            addChild(scanner)
            scanner.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(scanner.view)
            NSLayoutConstraint.activate([
                scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
                scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            scanner.didMove(toParent: self)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            do {
                try scanner.startScanning()
            } catch {
                onError(error.localizedDescription)
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            scanner.stopScanning()
            super.viewWillDisappear(animated)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            guard case .text(let text) = item else { return }
            onTextSelected(composePlateText(from: text))
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            updateRecognizedTextItems(allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            updateRecognizedTextItems(allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            updateRecognizedTextItems(allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            onError(error.localizedDescription)
        }

        private func updateRecognizedTextItems(_ items: [RecognizedItem]) {
            recognizedTextItems = Dictionary(
                uniqueKeysWithValues: items.compactMap { item in
                    guard case .text(let text) = item else { return nil }
                    return (text.id, text)
                }
            )
        }

        private func composePlateText(from selectedText: RecognizedItem.Text) -> String {
            let selectedFragment = PlateTextFragment(
                id: selectedText.id,
                transcript: selectedText.transcript,
                bounds: rect(for: selectedText.bounds)
            )
            let recognizedFragments = recognizedTextItems.values.map { text in
                PlateTextFragment(
                    id: text.id,
                    transcript: text.transcript,
                    bounds: rect(for: text.bounds)
                )
            }

            return PlateTextComposer.compose(
                selected: selectedFragment,
                recognizedFragments: recognizedFragments
            )
        }

        private func rect(for bounds: RecognizedItem.Bounds) -> CGRect {
            let points = [bounds.topLeft, bounds.topRight, bounds.bottomRight, bounds.bottomLeft]
            let minX = points.map(\.x).min() ?? 0
            let maxX = points.map(\.x).max() ?? 0
            let minY = points.map(\.y).min() ?? 0
            let maxY = points.map(\.y).max() ?? 0
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }
}
