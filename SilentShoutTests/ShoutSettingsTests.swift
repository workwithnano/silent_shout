import Foundation
import Testing
@testable import SilentShout

@MainActor
@Suite("ShoutSettings")
final class ShoutSettingsTests {
    let suiteName = "ShoutSettingsTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    @Test func originalKeyNames() {
        #expect(ShoutSettings.Key.text == "text")
        #expect(ShoutSettings.Key.font == "font")
        #expect(ShoutSettings.Key.texture == "texture")
        #expect(ShoutSettings.Key.lettering == "lettering")
    }

    @Test func defaultsWhenNothingIsStored() {
        let settings = ShoutSettings(defaults: defaults)
        #expect(settings.text == nil)
        #expect(settings.font == .pencil)
        #expect(settings.texture == .notecard)
        #expect(settings.sizing == .scaleToFit)
    }

    @Test func readsValuesStoredByTheOriginal() {
        defaults.set("Hello there", forKey: "text")
        defaults.set(1, forKey: "font")
        defaults.set(2, forKey: "texture")
        defaults.set(1, forKey: "lettering")
        let settings = ShoutSettings(defaults: defaults)
        #expect(settings.text == "Hello there")
        #expect(settings.font == .dryErase)
        #expect(settings.texture == .cardboard)
        #expect(settings.sizing == .scroll)
    }

    @Test func clampsOutOfRangeStoredValues() {
        defaults.set(-1, forKey: "font")
        defaults.set(3, forKey: "texture")
        defaults.set(2, forKey: "lettering")
        let settings = ShoutSettings(defaults: defaults)
        #expect(settings.font == .pencil)
        #expect(settings.texture == .cardboard)
        #expect(settings.sizing == .scroll)
    }

    @Test func clampsLargeStoredValues() {
        defaults.set(42, forKey: "font")
        defaults.set(-7, forKey: "texture")
        defaults.set(-1, forKey: "lettering")
        let settings = ShoutSettings(defaults: defaults)
        #expect(settings.font == .keyboard)
        #expect(settings.texture == .notecard)
        #expect(settings.sizing == .scaleToFit)
    }

    @Test func writesIntegersUnderTheOriginalKeys() {
        let settings = ShoutSettings(defaults: defaults)
        settings.font = .keyboard
        settings.texture = .whiteboard
        settings.sizing = .scroll
        #expect(defaults.object(forKey: "font") as? Int == 2)
        #expect(defaults.object(forKey: "texture") as? Int == 1)
        #expect(defaults.object(forKey: "lettering") as? Int == 1)
    }

    @Test func writesTextAsAString() {
        let settings = ShoutSettings(defaults: defaults)
        settings.text = "SHOUT"
        #expect(defaults.object(forKey: "text") as? String == "SHOUT")
    }

    @Test func clearingTextRemovesTheKey() {
        defaults.set("old", forKey: "text")
        let settings = ShoutSettings(defaults: defaults)
        settings.text = nil
        #expect(defaults.object(forKey: "text") == nil)
    }

    @Test func emptyTextIsStoredAsEmpty() {
        let settings = ShoutSettings(defaults: defaults)
        settings.text = ""
        #expect(defaults.string(forKey: "text") == "")
        #expect(ShoutSettings(defaults: defaults).text == "")
    }

    @Test func valuesSurviveANewInstance() {
        let first = ShoutSettings(defaults: defaults)
        first.text = "Over here"
        first.font = .dryErase
        first.texture = .cardboard
        first.sizing = .scroll
        let second = ShoutSettings(defaults: defaults)
        #expect(second.text == "Over here")
        #expect(second.font == .dryErase)
        #expect(second.texture == .cardboard)
        #expect(second.sizing == .scroll)
    }

    @Test func loadingDoesNotWrite() {
        _ = ShoutSettings(defaults: defaults)
        #expect(defaults.object(forKey: "font") == nil)
        #expect(defaults.object(forKey: "texture") == nil)
        #expect(defaults.object(forKey: "lettering") == nil)
        #expect(defaults.object(forKey: "text") == nil)
    }
}
