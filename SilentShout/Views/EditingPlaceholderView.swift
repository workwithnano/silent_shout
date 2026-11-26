import SwiftUI

/// PLACEHOLDER for phase 2 only: stands in for the Editing screen so the Next button has
/// somewhere to go. Phase 3 replaces this view with the real Editing screen (text bar,
/// live preview) and points `AppRoute.editing` at it in `RootView`.
struct EditingPlaceholderView: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    navigation.pop()
                } label: {
                    Text("Back")
                }
                .buttonStyle(ImageButtonStyle(up: .backUp, down: .backDown))
                .frame(width: 44, height: 44)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("editing.back")
                Spacer()
            }
            .padding(.horizontal, 6)

            Spacer()
            Text("Editing screen")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .accessibilityIdentifier("editing.placeholder")
            Text("Placeholder: the text bar and live preview arrive in phase 3.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .background { MainBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { OrientationLock.set(.portrait) }
    }
}
