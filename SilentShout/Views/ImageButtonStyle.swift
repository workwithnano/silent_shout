import SwiftUI

/// A button drawn entirely by the original art, like the 2011 custom UIButtons: `up` normally,
/// `down` while pressed, and `selected` (when given) while the button is in its selected state.
/// The art is shown at its own point size, unscaled (PLAN ruling 7).
struct ImageButtonStyle: ButtonStyle {
    let up: ChromeImage
    let down: ChromeImage
    var selected: ChromeImage? = nil
    var isSelected = false
    /// When set, the tappable area is at least this many points square, with the art centred
    /// in it (PLAN ruling 7: 44 pt targets around smaller art).
    var minimumTapSize: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        let image: ChromeImage = if configuration.isPressed {
            down
        } else if isSelected, let selected {
            selected
        } else {
            up
        }
        Image(image.rawValue)
            .frame(minWidth: minimumTapSize, minHeight: minimumTapSize)
            .contentShape(Rectangle())
    }
}
