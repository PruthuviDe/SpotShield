import CoreGraphics
import Foundation

struct PlateTextFragment {
    var id: UUID
    var transcript: String
    var bounds: CGRect
}

enum PlateTextComposer {
    static func compose(
        selected: PlateTextFragment,
        recognizedFragments: [PlateTextFragment]
    ) -> String {
        let selectedBounds = selected.bounds
        let minimumHeight = max(0.022, min(selectedBounds.height * 0.32, 0.075))
        var nearbyFragments = recognizedFragments.filter { fragment in
            let bounds = fragment.bounds
            return fragment.id == selected.id ||
                (bounds.height >= minimumHeight &&
                 abs(bounds.midX - selectedBounds.midX) <= 0.65 &&
                 abs(bounds.midY - selectedBounds.midY) <= 0.55)
        }

        if !nearbyFragments.contains(where: { $0.id == selected.id }) {
            nearbyFragments.append(selected)
        }

        let tokens = nearbyFragments.flatMap { fragment -> [(value: String, category: Int, x: CGFloat, order: Int)] in
            fragment.transcript
                .uppercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .enumerated()
                .map { index, token in
                    let category = token.allSatisfy(\.isLetter) ? 0 :
                        (token.allSatisfy(\.isNumber) ? 2 : 1)
                    return (token, category, fragment.bounds.midX, index)
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

        return composed.isEmpty ? selected.transcript : composed
    }
}
