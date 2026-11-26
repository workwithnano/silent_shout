import Foundation
import Observation
import UIKit

/// The four persisted settings, under the keys and types 1.0.1 used (SPEC.md section 4),
/// so values stored by the original keep their meaning, plus the rewrite's camera background
/// under a key of its own.
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
        /// Bool: the stored photo, not `texture`, is the background. A separate key, so
        /// `texture` keeps its original meaning (0 to 2, out-of-range values clamped) and still
        /// says which paper the carousel shows and which texture to fall back to.
        static let photoBackground = "photoBackground"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let photoStore: PhotoBackgroundStore

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

    /// True while the stored photo is the background. Only ever true with `photo` loaded: a
    /// missing or unreadable file falls back to the texture.
    private(set) var usesPhoto: Bool {
        didSet { defaults.set(usesPhoto, forKey: Key.photoBackground) }
    }

    /// The stored photo once loaded (at launch when it is the background, or when chosen).
    /// Kept after switching back to a texture, for "Use Last Photo".
    private(set) var photo: ShoutBackground? {
        didSet { if photo != oldValue { photoThumbnail = Self.thumbnail(of: photo) } }
    }

    /// A small copy of `photo` for the carousel's camera entry.
    private(set) var photoThumbnail: UIImage?

    private static func thumbnail(of photo: ShoutBackground?) -> UIImage? {
        guard let image = photo?.image, image.size.width > 0, image.size.height > 0 else { return nil }
        let factor = 300 / min(image.size.width, image.size.height)
        guard factor < 1 else { return image }
        return image.preparingThumbnail(of: CGSize(width: image.size.width * factor, height: image.size.height * factor)) ?? image
    }

    /// What the shout and the preview are drawn on.
    var background: ShoutBackground {
        if usesPhoto, let photo { return photo }
        return .texture(texture)
    }

    /// The photo when it is the background, else nil (the preview then uses the texture's
    /// own preview art).
    var activePhoto: UIImage? {
        usesPhoto ? photo?.image : nil
    }

    /// Whether "Use Last Photo" has something to use.
    var hasStoredPhoto: Bool { photo != nil || photoStore.hasPhoto }

    /// Stores `image` (already prepared by `PhotoProcessing`) and makes it the background.
    func usePhoto(_ image: UIImage) throws {
        photo = try photoStore.save(image)
        usesPhoto = true
    }

    /// Makes the stored photo the background again. False (nothing changes) if there is none.
    @discardableResult
    func useLastPhoto() -> Bool {
        if photo == nil { photo = photoStore.load() }
        guard photo != nil else { return false }
        usesPhoto = true
        return true
    }

    /// The user chose a paper texture in the carousel: it becomes the background. The photo
    /// stays stored.
    func useTexture(_ texture: ShoutTexture) {
        if self.texture != texture { self.texture = texture }
        if usesPhoto { usesPhoto = false }
    }

    /// Removes every stored key, returning every setting to the original default, and the
    /// stored photo. UI tests ask for this at launch (`UITestHooks.resetSettings`).
    nonisolated static func resetStoredOptions(
        in defaults: UserDefaults = .standard,
        photoStore: PhotoBackgroundStore = .standard
    ) {
        for key in [Key.text, Key.font, Key.texture, Key.lettering, Key.photoBackground] {
            defaults.removeObject(forKey: key)
        }
        photoStore.remove()
    }

    init(defaults: UserDefaults = .standard, photoStore: PhotoBackgroundStore = .standard) {
        self.defaults = defaults
        self.photoStore = photoStore
        // `integer(forKey:)` gives 0 for an absent key, which is the original's default for all three.
        text = defaults.string(forKey: Key.text)
        font = .clamped(defaults.integer(forKey: Key.font))
        texture = .clamped(defaults.integer(forKey: Key.texture))
        sizing = .clamped(defaults.integer(forKey: Key.lettering))
        let wantsPhoto = defaults.bool(forKey: Key.photoBackground)
        let stored = wantsPhoto ? photoStore.load() : nil
        photo = stored
        photoThumbnail = Self.thumbnail(of: stored)
        usesPhoto = stored != nil
        if wantsPhoto, stored == nil {
            // The file is gone (or unreadable): back to the texture, and remember that.
            defaults.set(false, forKey: Key.photoBackground)
        }
    }
}
