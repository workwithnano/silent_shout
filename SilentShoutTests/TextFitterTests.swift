import CoreGraphics
import Testing
import UIKit
@testable import SilentShout

@Suite("Text fitter")
struct TextFitterTests {
    static let fontNames = ShoutFont.allCases.map(\.fontName)

    // MARK: The rule, with a fake measurer

    @Test func triesMaxDownToMinByStep() {
        let sizes = TextFitter.preview.candidateSizes
        #expect(sizes.first == 200)
        #expect(sizes.last == 12)
        #expect(sizes.count == 95)
        #expect(zip(sizes, sizes.dropFirst()).allSatisfy { $0 - $1 == 2 })

        let shout = TextFitter.shout.candidateSizes
        #expect(shout.first == 360)
        #expect(shout.last == 12)
    }

    @Test func stopsAtTheFirstSizeThatFits() {
        // Height grows linearly with size; 206 / 1.5 = 137.3, so 136 is the first even size that fits.
        let size = TextFitter.preview.fontSize { $0 * 1.5 }
        #expect(size == 136)
        // Exactly at the limit counts as fitting (<=).
        #expect(TextFitter.preview.fontSize { $0 == 150 ? 206 : 1000 } == 150)
    }

    @Test func floorsAtTheMinimumWhenNothingFits() {
        #expect(TextFitter.preview.fontSize { _ in .infinity } == 12)
        #expect(TextFitter.shout.fontSize { _ in 10_000 } == 12)
    }

    @Test func maxWhenEverythingFits() {
        #expect(TextFitter.preview.fontSize { _ in 0 } == 200)
        #expect(TextFitter.shout.fontSize { _ in 280 } == 360)
    }

    @Test func parametersAreUsed() {
        let fitter = TextFitter(boxWidth: 100, boxHeight: 50, maxSize: 40, minSize: 20, step: 5)
        #expect(fitter.candidateSizes == [40, 35, 30, 25, 20])
        #expect(fitter.fontSize { $0 * 2 } == 25)
        #expect(fitter.fontSize { _ in 51 } == 20)
    }

    // MARK: Real measurement, in the app's fonts

    @Test(arguments: fontNames)
    func emptyTextGetsTheMaximum(fontName: String) {
        #expect(TextFitter.preview.fontSize(for: "", fontName: fontName) == 200)
        #expect(TextFitter.shout.fontSize(for: "", fontName: fontName) == 360)
    }

    @Test(arguments: fontNames)
    func longerTextNeverGetsABiggerSize(fontName: String) {
        let message = "Happy birthday Grandma, we love you very much and we are sorry we missed the party, see you at the lake next summer with the whole family"
        var previous = CGFloat.infinity
        var text = ""
        for character in message {
            text.append(character)
            let size = TextFitter.preview.fontSize(for: text, fontName: fontName)
            #expect(size <= previous, "\"\(text)\" got \(size) after \(previous)")
            previous = size
        }
        #expect(previous < 60, "the whole message should be well below the maximum")
    }

    @Test(arguments: fontNames)
    func resultFitsAndTheNextSizeUpDoesNot(fontName: String) {
        for text in ["Hi", "Go team!", "Can you pick up milk on the way home", "Supercalifragilisticexpialidocious"] {
            let fitter = TextFitter.preview
            let size = fitter.fontSize(for: text, fontName: fontName)
            #expect(size > fitter.minSize, "\(text)")
            #expect(height(text, fontName, size, fitter) <= fitter.boxHeight, "\(text) at \(size)")
            if size < fitter.maxSize {
                #expect(height(text, fontName, size + fitter.step, fitter) > fitter.boxHeight, "\(text) at \(size + 2)")
            }
        }
    }

    @Test(arguments: fontNames)
    func aSingleLongWordShrinksAndBreaksInsideTheBox(fontName: String) {
        let word = "Antidisestablishmentarianism"
        let size = TextFitter.preview.fontSize(for: word, fontName: fontName)
        #expect(size < TextFitter.preview.fontSize(for: "Anti", fontName: fontName))
        #expect(size > TextFitter.preview.minSize)
        #expect(height(word, fontName, size, .preview) <= 206)
    }

    @Test(arguments: fontNames)
    func veryLongTextFloorsAtTheMinimum(fontName: String) {
        let text = String(repeating: "This message is far too long to fit. ", count: 60)
        #expect(TextFitter.preview.fontSize(for: text, fontName: fontName) == 12)
        #expect(TextFitter.shout.fontSize(for: text, fontName: fontName) == 12)
    }

    @Test func shortTextIsLargerOnTheShoutThanInThePreview() {
        let text = "See you at noon"
        let preview = TextFitter.preview.fontSize(for: text, fontName: "Helvetica")
        let shout = TextFitter.shout.fontSize(for: text, fontName: "Helvetica")
        #expect(shout > preview)
    }

    @Test func unknownFontFallsBackToTheSystemFont() {
        let size = TextFitter.preview.fontSize(for: "Hello", fontName: "NoSuchFont")
        #expect(size > 12 && size <= 200)
    }

    private func height(_ text: String, _ fontName: String, _ size: CGFloat, _ fitter: TextFitter) -> CGFloat {
        let font = UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
        return TextFitter.wrappedHeight(of: text, font: font, width: fitter.boxWidth)
    }
}
