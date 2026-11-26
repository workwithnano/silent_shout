import SwiftUI

/// One sizing option's 40-frame image loop, 5 s per loop, always running (SPEC.md section 3).
/// The original played these as a `UIImageView` animation; a timeline at the same frame rate
/// gives the same result.
struct SizingAnimationView: View {
    let sizing: ShoutSizing
    @State private var start = Date.now

    var body: some View {
        TimelineView(.periodic(from: start, by: SizingAnimation.frameInterval)) { context in
            let index = SizingAnimation.frameIndex(elapsed: context.date.timeIntervalSince(start))
            Image(sizing.frameImageNames[index])
        }
    }
}
