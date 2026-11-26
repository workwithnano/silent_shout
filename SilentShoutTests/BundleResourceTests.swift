import Testing
import UIKit
@testable import SilentShout

/// Unit tests run hosted in the app, so `Bundle.main` is the app bundle and the fonts listed
/// in its UIAppFonts are registered.
@Suite("Bundled fonts and images")
struct BundleResourceTests {
    // MARK: Fonts (SPEC.md open point 1)

    @Test(arguments: ShoutFont.allCases)
    func everyFontResolves(font: ShoutFont) {
        #expect(UIFont(name: font.fontName, size: 20) != nil, "\(font.fontName) is not registered")
    }

    /// The names iOS registers for the bundled files, read from UIFont at runtime.
    @Test func registeredFontNames() {
        print("Registered fonts for Later On:", UIFont.fontNames(forFamilyName: "Later On"))
        print("Registered fonts for Kristi:", UIFont.fontNames(forFamilyName: "Kristi"))
        #expect(UIFont.familyNames.contains("Later On"))
        #expect(UIFont.fontNames(forFamilyName: "Later On") == ["lateron"])
        #expect(UIFont.familyNames.contains("Kristi"))
        #expect(UIFont.fontNames(forFamilyName: "Kristi") == ["Kristi"])
        #expect(UIFont(name: "lateron", size: 20)?.familyName == "Later On")
        #expect(UIFont(name: "Kristi", size: 20)?.familyName == "Kristi")
    }

    @Test func bundledFontFilesArePresent() {
        for file in ShoutFont.allCases.compactMap(\.fileName) {
            let parts = file.split(separator: ".")
            #expect(Bundle.main.url(forResource: String(parts[0]), withExtension: String(parts[1])) != nil, "\(file) missing")
        }
        let appFonts = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String]
        #expect(Set(appFonts ?? []) == ["later_on.ttf", "Kristi.ttf"])
    }

    @Test func soundFileIsNotBundled() {
        #expect(Bundle.main.url(forResource: "swish", withExtension: "caf") == nil)
    }

    // MARK: Images

    static var allImageNames: [String] {
        ShoutTexture.allCases.flatMap { [$0.shoutImageName, $0.previewImageName, $0.carouselImageName] }
            + [ShoutTexture.cameraCarouselImageName]
            + ShoutFont.allCases.map(\.carouselImageName)
            + ShoutSizing.allCases.flatMap(\.frameImageNames)
            + ChromeImage.allCases.map(\.rawValue)
    }

    @Test func everyImageLoadsFromTheAssetCatalog() {
        let missing = Self.allImageNames.filter { UIImage(named: $0) == nil }
        #expect(missing.isEmpty, "missing images: \(missing)")
        #expect(Self.allImageNames.count == 9 + 1 + 3 + 80 + ChromeImage.allCases.count)
    }

    /// Art keeps its original point size (1x pixels), so layouts can use SPEC.md's numbers.
    @Test(arguments: [
        ("bkgrd_texture-notecards", CGSize(width: 480, height: 320)),
        // The original preview @2x art is 639x451 px, half a point short of its 320x226 1x art.
        ("bkgrd_texture-previewnotecard", CGSize(width: 319.5, height: 225.5)),
        ("icon-texture_notecard", CGSize(width: 200, height: 100)),
        ("scale_00000", CGSize(width: 200, height: 100)),
        ("Scroll-Your-Note_00039", CGSize(width: 200, height: 100)),
        ("btns_next_UP", CGSize(width: 48, height: 48)),
        ("btns_help_UP", CGSize(width: 48, height: 48)),
        ("help_bubble-writingtool", CGSize(width: 103, height: 45)),
        ("toolbar_Textfield", CGSize(width: 320, height: 41)),
    ])
    func imagePointSizes(name: String, size: CGSize) {
        #expect(UIImage(named: name)?.size == size)
    }
}
