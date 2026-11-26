import SwiftUI
import Testing
import UIKit
@testable import SilentShout

/// Where an `OptionCarousel` rests when it first appears, read from the `UIScrollView` SwiftUI
/// draws it with. The carousel is hosted in a window of its own, laid out synchronously.
@Suite("Option carousel start position", .serialized)
@MainActor
struct OptionCarouselTests {
    @Observable
    @MainActor
    final class Model {
        var width: CGFloat
        var font: ShoutFont
        var restingPage: Int?
        /// Every value the carousel wrote to its selection.
        var writes: [ShoutFont] = []

        init(width: CGFloat, font: ShoutFont, restingPage: Int? = nil) {
            self.width = width
            self.font = font
            self.restingPage = restingPage
        }
    }

    struct Harness: View {
        let model: Model

        var body: some View {
            OptionCarousel(
                title: "Writing tool",
                identifier: "carousel",
                pageWidth: model.width,
                selection: Binding(get: { model.font }, set: { model.font = $0; model.writes.append($0) }),
                restingPage: model.restingPage,
                accessibilityName: \.accessibilityName
            ) { font in
                Image(font.carouselImageName)
            } trailing: {
                EmptyView()
            }
        }
    }

    /// A window showing the carousel, and its scroll view after one synchronous layout.
    @MainActor
    private final class Host {
        let window: UIWindow
        let controller: UIHostingController<Harness>

        init(_ model: Model) throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 440, height: 200)
            controller = UIHostingController(rootView: Harness(model: model))
            window.rootViewController = controller
            window.isHidden = false
            layout()
        }

        func layout() {
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }

        var scrollView: UIScrollView? { Self.firstScrollView(in: controller.view) }

        func close() { window.isHidden = true }

        private static func firstScrollView(in view: UIView) -> UIScrollView? {
            if let scrollView = view as? UIScrollView { return scrollView }
            for subview in view.subviews {
                if let found = firstScrollView(in: subview) { return found }
            }
            return nil
        }
    }

    /// Layout works in fractions of a pixel; a page off would be hundreds of points.
    private static func isClose(_ value: CGFloat, _ expected: CGFloat) -> Bool {
        abs(value - expected) < 1
    }

    @Test(arguments: [CGFloat(320), 375, 402, 440], ShoutFont.allCases)
    func startsOnTheStoredPage(width: CGFloat, font: ShoutFont) throws {
        let model = Model(width: width, font: font)
        let host = try Host(model)
        defer { host.close() }
        let scrollView = try #require(host.scrollView)
        #expect(Self.isClose(scrollView.contentOffset.x, width * CGFloat(font.rawValue)))
        #expect(model.writes.isEmpty, "positioning is not a choice")
    }

    /// The first layout pass can come before the page width is known (0); the carousel still
    /// ends on the stored page once it is.
    @Test func startsOnTheStoredPageWhenTheWidthArrivesLate() throws {
        let model = Model(width: 0, font: .keyboard)
        let host = try Host(model)
        defer { host.close() }
        model.width = 402
        host.layout()
        let scrollView = try #require(host.scrollView)
        #expect(Self.isClose(scrollView.contentSize.width, 402 * 3))
        #expect(Self.isClose(scrollView.contentOffset.x, 402 * 2))
        #expect(model.writes.isEmpty)
    }

    /// The texture carousel rests on its last page while the photo is the background, whatever
    /// texture is stored underneath.
    @Test func restingPageWinsOverTheSelection() throws {
        let model = Model(width: 402, font: .pencil, restingPage: 2)
        let host = try Host(model)
        defer { host.close() }
        let scrollView = try #require(host.scrollView)
        #expect(Self.isClose(scrollView.contentOffset.x, 402 * 2))
        #expect(model.writes.isEmpty)
        #expect(model.font == .pencil)
    }
}
