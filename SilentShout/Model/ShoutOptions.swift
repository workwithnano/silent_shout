import SwiftUI
import UIKit

/// An option stored in UserDefaults as its integer index, exactly as 1.0.1 stored it.
protocol StoredOption: CaseIterable, RawRepresentable, Sendable where RawValue == Int, AllCases == [Self] {}

extension StoredOption {
    /// The option for a stored index. Out-of-range values (including the -1 and `count`
    /// the original could store while a carousel over-scrolled) are clamped to the
    /// nearest valid option rather than reproducing the original's fall-through cases.
    static func clamped(_ index: Int) -> Self {
        let first = allCases.first!.rawValue
        let last = allCases.last!.rawValue
        return Self(rawValue: min(max(index, first), last))!
    }
}

/// An ink colour as the 0xRRGGBB value the original passed to `UIColorFromRGB`.
struct InkColor: Equatable, Sendable {
    let rgb: UInt32

    var red: Double { Double((rgb >> 16) & 0xFF) / 255 }
    var green: Double { Double((rgb >> 8) & 0xFF) / 255 }
    var blue: Double { Double(rgb & 0xFF) / 255 }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
}

/// The "writing tool" carousel (UserDefaults key `font`). SPEC.md section 5.
enum ShoutFont: Int, StoredOption {
    case pencil = 0
    case dryErase = 1
    case keyboard = 2

    /// The name passed to `UIFont(name:size:)`. "lateron" is the PostScript name iOS
    /// registers for `later_on.ttf` (the original code passed "Later On", its family name).
    var fontName: String {
        switch self {
        case .pencil: "lateron"
        case .dryErase: "Kristi"
        case .keyboard: "Helvetica"
        }
    }

    /// The bundled file, or nil for the system font.
    var fileName: String? {
        switch self {
        case .pencil: "later_on.ttf"
        case .dryErase: "Kristi.ttf"
        case .keyboard: nil
        }
    }

    var ink: InkColor {
        switch self {
        case .pencil: InkColor(rgb: 0x000000)
        case .dryErase: InkColor(rgb: 0xE93232)
        case .keyboard: InkColor(rgb: 0x000000)
        }
    }

    var carouselImageName: String {
        switch self {
        case .pencil: "icon-lettering_pencil"
        case .dryErase: "icon-lettering_reddryerase"
        case .keyboard: "icon-lettering_keyboard"
        }
    }

    /// Spoken by VoiceOver. The original never showed option names; these describe the art.
    var accessibilityName: String {
        switch self {
        case .pencil: "Pencil"
        case .dryErase: "Red dry-erase marker"
        case .keyboard: "Keyboard"
        }
    }

    func uiFont(size: CGFloat) -> UIFont? { UIFont(name: fontName, size: size) }
    func font(size: CGFloat) -> Font { .custom(fontName, fixedSize: size) }
}

/// The "background" carousel (UserDefaults key `texture`). SPEC.md sections 3 and 6.4.
enum ShoutTexture: Int, StoredOption {
    case notecard = 0
    /// Called "Postcard" in the original code; it shows and produces the whiteboard.
    case whiteboard = 1
    case cardboard = 2

    /// Full-screen shout background (480x320 points of art).
    var shoutImageName: String {
        switch self {
        case .notecard: "bkgrd_texture-notecards"
        case .whiteboard: "bkgrd_texture-whiteboard"
        case .cardboard: "bkgrd_texture-cardboard"
        }
    }

    /// Editing-screen preview background (320x226 points of art).
    var previewImageName: String {
        switch self {
        case .notecard: "bkgrd_texture-previewnotecard"
        case .whiteboard: "bkgrd_texture-previewwhiteboard"
        case .cardboard: "bkgrd_texture-previewcardboard"
        }
    }

    var carouselImageName: String {
        switch self {
        case .notecard: "icon-texture_notecard"
        case .whiteboard: "icon-texture_whiteboard"
        case .cardboard: "icon-texture_cardboard"
        }
    }

    /// Spoken by VoiceOver.
    var accessibilityName: String {
        switch self {
        case .notecard: "Notecard"
        case .whiteboard: "Whiteboard"
        case .cardboard: "Cardboard"
        }
    }

    /// The camera entry 1.0.1 appended after the textures (finished in phase 5).
    static let cameraCarouselImageName = "icon-texture_camera"
}

/// The "presentation" carousel (UserDefaults key `lettering`). SPEC.md sections 2.3 and 3.
enum ShoutSizing: Int, StoredOption {
    case scaleToFit = 0
    case scroll = 1

    static let frameCount = 40
    /// One loop of the carousel animation: 40 frames in 5 s (8 fps), repeating forever.
    static let animationDuration: Double = 5.0

    var framePrefix: String {
        switch self {
        case .scaleToFit: "scale_"
        case .scroll: "Scroll-Your-Note_"
        }
    }

    /// Spoken by VoiceOver; the words the animations themselves show.
    var accessibilityName: String {
        switch self {
        case .scaleToFit: "Scale your note"
        case .scroll: "Scroll your note"
        }
    }

    /// `scale_00000` ... `scale_00039`, or the `Scroll-Your-Note_` equivalents.
    var frameImageNames: [String] {
        (0..<Self.frameCount).map { framePrefix + String(format: "%05d", $0) }
    }
}

/// Fixed interface art by its asset catalog name (SPEC.md section 10).
enum ChromeImage: String, CaseIterable, Sendable {
    case mainBackground = "bkgrnd_main"
    case launchPoster = "poster_001"
    case helpUp = "btns_help_UP"
    case helpDown = "btns_help_DOWN"
    case helpActive = "btns_help_ACTIVE"
    case nextUp = "btns_next_UP"
    case nextDown = "btns_next_DOWN"
    case backUp = "btns_back_UP"
    case backDown = "btns_back_DOWN"
    case back2Up = "btns_back2_UP"
    case back2Down = "btns_back2_DOWN"
    case doubleBackUp = "btns_doubleback_UP"
    case doubleBackDown = "btns_doubleback_DOWN"
    case shareUp = "btns_share_UP"
    case shareDown = "btns_share_DOWN"
    case helpBubbleWritingTool = "help_bubble-writingtool"
    case helpBubbleBackground = "help_bubble-background"
    case helpBubblePresentation = "help_bubble-presentation"
    case textBar = "toolbar_Textfield"
    case textField = "textfield"
    /// The shout's toolbar background (480x44): a black gradient matching the original's
    /// black-style `UIToolbar`. 1.0.1 bundled it but drew the system bar instead (SPEC.md 7).
    case shoutToolbar = "toolbar_shoutoverlay"
}
