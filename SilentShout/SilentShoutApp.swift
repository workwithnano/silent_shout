import SwiftUI

@main
struct SilentShoutApp: App {
    @State private var settings = ShoutSettings()

    var body: some Scene {
        WindowGroup {
            PlaceholderView()
                .environment(settings)
        }
    }
}
