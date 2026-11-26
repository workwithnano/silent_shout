import SwiftUI

/// STUB (phase 3). Stands in for the Shout screen so the Done key and the rotation on
/// Editing have somewhere to go. It is presented by `ShoutPresenter` (full screen,
/// cross-dissolve) whenever `AppNavigation.isShouting` is true, and its back button calls
/// `AppNavigation.endShout()`, which returns to Editing with the keyboard up.
///
/// Phase 4 replaces this body with the real shout (SPEC.md sections 2.3, 6.2, 6.3, 7):
/// landscape, fit or marquee, the tap-to-show toolbar with back, double-back and share.
struct ShoutView: View {
    @Environment(ShoutSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        VStack(spacing: 16) {
            Text("Shout screen (stub)")
                .font(.headline)
                .accessibilityIdentifier("shout.stub")
            Text(settings.text ?? "")
                .font(.title)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("shout.text")
            Text("Phase 4 builds the real shout.")
                .font(.footnote)
            Button {
                navigation.endShout()
            } label: {
                Text("Back")
            }
            .buttonStyle(ImageButtonStyle(up: .back2Up, down: .back2Down))
            .frame(width: 44, height: 44)
            .accessibilityLabel("Back 1 Step")
            .accessibilityIdentifier("shout.back")
        }
        .foregroundStyle(.black)
        .padding(24)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Image(settings.texture.shoutImageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }
}
