import Foundation
import Observation

/// The four persisted settings, under the keys and types 1.0.1 used (SPEC.md section 4),
/// so values stored by the original keep their meaning.
///
/// Every assignment writes through to UserDefaults immediately. The original wrote `text`
/// only when editing ended; screens that edit text should hold it locally and assign it here
/// when the screen changes (PLAN.md ruling 9).
@Observable
@MainActor
final class ShoutSettings {
    enum Key {
        static let text = "text"
        static let font = "font"
        static let texture = "texture"
        static let lettering = "lettering"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// nil when never saved: the field starts empty and the shout shows the bare texture.
    var text: String? {
        didSet {
            if let text { defaults.set(text, forKey: Key.text) } else { defaults.removeObject(forKey: Key.text) }
        }
    }

    var font: ShoutFont {
        didSet { defaults.set(font.rawValue, forKey: Key.font) }
    }

    var texture: ShoutTexture {
        didSet { defaults.set(texture.rawValue, forKey: Key.texture) }
    }

    var sizing: ShoutSizing {
        didSet { defaults.set(sizing.rawValue, forKey: Key.lettering) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `integer(forKey:)` gives 0 for an absent key, which is the original's default for all three.
        text = defaults.string(forKey: Key.text)
        font = .clamped(defaults.integer(forKey: Key.font))
        texture = .clamped(defaults.integer(forKey: Key.texture))
        sizing = .clamped(defaults.integer(forKey: Key.lettering))
    }
}
