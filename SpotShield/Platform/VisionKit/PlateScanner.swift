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
            let selectedBounds = rect(for: selectedText.bounds)
            let minimumHeight = max(0.022, min(selectedBounds.height * 0.32, 0.075))
            var nearbyTexts = recognizedTextItems.values.filter { text in
                let bounds = rect(for: text.bounds)
                return text.id == selectedText.id ||
                    (bounds.height >= minimumHeight &&
                     abs(bounds.midX - selectedBounds.midX) <= 0.65 &&
                     abs(bounds.midY - selectedBounds.midY) <= 0.55)
            }
            if !nearbyTexts.contains(where: { $0.id == selectedText.id }) {
                nearbyTexts.append(selectedText)
            }

            let tokens = nearbyTexts.flatMap { text -> [(value: String, category: Int, x: CGFloat, order: Int)] in
                let bounds = rect(for: text.bounds)
                return text.transcript
                    .uppercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }
                    .enumerated()
                    .map { index, token in
                        let category = token.allSatisfy(\.isLetter) ? 0 :
                            (token.allSatisfy(\.isNumber) ? 2 : 1)
                        return (token, category, bounds.midX, index)
                    }
            }

            let composed = tokens
                .sorted {
                    if $0.category != $1.category { return $0.category < $1.category }
                    if $0.x != $1.x { return $0.x < $1.x }
                    return $0.order < $1.order
                }
                .map(\.value)
                .joined(separator: " ")

            return composed.isEmpty ? selectedText.transcript : composed
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
