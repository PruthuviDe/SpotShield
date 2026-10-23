import CoreGraphics
import Foundation
import Testing
@testable import SpotShield

@Suite("Plate text composition")
struct PlateTextComposerTests {
    @Test("Text fragments from two rows form one plate")
    func composesTwoRowPlate() {
        let letters = fragment("SPND", x: 0.2, y: 0.25)
        let digits = fragment("4957", x: 0.35, y: 0.67)

        #expect(PlateTextComposer.compose(
            selected: letters,
            recognizedFragments: [letters, digits]
        ) == "SPND 4957")
    }

    @Test("Letter fragments are ordered left to right before digits")
    func ordersLetterGroupsBeforeDigits() {
        let firstLetters = fragment("CP", x: 0.1, y: 0.3)
        let secondLetters = fragment("CAG", x: 0.48, y: 0.3)
        let digits = fragment("5364", x: 0.65, y: 0.65)

        #expect(PlateTextComposer.compose(
            selected: firstLetters,
            recognizedFragments: [digits, secondLetters, firstLetters]
        ) == "CP CAG 5364")
    }

    @Test("Punctuation is removed from recognized plate text")
    func removesPunctuationFromFragments() {
        let letters = fragment("QL", x: 0.1, y: 0.3)
        let mixed = fragment("SP-9904", x: 0.5, y: 0.3)

        #expect(PlateTextComposer.compose(
            selected: letters,
            recognizedFragments: [letters, mixed]
        ) == "QL SP 9904")
    }

    @Test("Unrelated or too-small text is excluded")
    func excludesUnrelatedText() {
        let selected = fragment("CP", x: 0.1, y: 0.3)
        let unrelated = fragment("WATERMARK", x: 0.95, y: 0.3)
        let small = fragment("2026", x: 0.2, y: 0.32, height: 0.01)

        #expect(PlateTextComposer.compose(
            selected: selected,
            recognizedFragments: [selected, unrelated, small]
        ) == "CP")
    }

    private func fragment(
        _ transcript: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 0.2,
        height: CGFloat = 0.12
    ) -> PlateTextFragment {
        PlateTextFragment(
            id: UUID(),
            transcript: transcript,
            bounds: CGRect(x: x, y: y, width: width, height: height)
        )
    }
}
