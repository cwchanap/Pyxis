import CoreGraphics
import Testing
@testable import Pyxis

struct SingleLineTextFitterTests {
    @Test func returnsFirstWholePointSizeThatFits() {
        let result = SingleLineTextFitter.fittedFontSize(
            "AB",
            startingAt: 7.8,
            minimum: 4,
            maximumWidth: 10,
            measure: { text, size in CGFloat(text.count) * size }
        )
        #expect(result == 5)
    }

    @Test func includesTheMinimumSize() {
        let result = SingleLineTextFitter.fittedFontSize(
            "ABC",
            startingAt: 6,
            minimum: 4,
            maximumWidth: 12,
            measure: { text, size in CGFloat(text.count) * size }
        )
        #expect(result == 4)
    }

    @Test func returnsNilWhenMinimumDoesNotFit() {
        let result = SingleLineTextFitter.fittedFontSize(
            "ABC",
            startingAt: 6,
            minimum: 4,
            maximumWidth: 11,
            measure: { text, size in CGFloat(text.count) * size }
        )
        #expect(result == nil)
    }
}
