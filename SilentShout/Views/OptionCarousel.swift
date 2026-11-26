import SwiftUI

/// One horizontal paging option carousel (SPEC.md section 3): one screen-wide page per option
/// with the option's art centred in it, starting on the stored option, and writing the option
/// back as the user scrolls, switching at 50% of the way to the next page.
///
/// `trailing` is laid out after the last page but is not a page: it never becomes the
/// selection, the page dots do not count it, and it adds no scrollable width (give it zero
/// width and draw it back over the last page, as the texture carousel's camera entry does).
/// It stays outside the carousel's single accessibility element, so a button in it is its own
/// element.
///
/// `restingPage`, when set, is where the carousel rests instead of the selection's page (the
/// texture carousel rests on its last page, next to the camera entry, while the photo is the
/// background); `valueOverride` replaces the spoken value meanwhile. `onUserChoice` is told
/// each time the user settles on an option (the carousel comes to rest after a drag, or a
/// VoiceOver swipe), even if it is the one already selected.
struct OptionCarousel<Option: StoredOption & Hashable, Page: View, Trailing: View>: View {
    let title: String
    let identifier: String
    let pageWidth: CGFloat
    @Binding var selection: Option
    var restingPage: Int? = nil
    var valueOverride: String? = nil
    var onUserChoice: (Option) -> Void = { _ in }
    let accessibilityName: (Option) -> String
    let page: (Option) -> Page
    let trailing: () -> Trailing

    /// Only for moving the carousel after it is on screen (a VoiceOver adjust, the photo
    /// coming into use). Where it starts is `startAnchor`'s job: on iOS 27, at least, a
    /// `ScrollPosition` created with an id does not scroll there on the first layout; the scroll
    /// view starts at offset 0 and the position goes on reporting the id it was given.
    @State private var position = ScrollPosition(idType: Int.self)
    /// True from the moment the user touches the carousel until it comes to rest. Offset
    /// changes outside that window (the initial positioning, layout passes) are not choices.
    @State private var userDriven = false
    @State private var lastOffset: CGFloat = 0

    init(
        title: String,
        identifier: String,
        pageWidth: CGFloat,
        selection: Binding<Option>,
        restingPage: Int? = nil,
        valueOverride: String? = nil,
        onUserChoice: @escaping (Option) -> Void = { _ in },
        accessibilityName: @escaping (Option) -> String,
        @ViewBuilder page: @escaping (Option) -> Page,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.identifier = identifier
        self.pageWidth = pageWidth
        _selection = selection
        self.restingPage = restingPage
        self.valueOverride = valueOverride
        self.onUserChoice = onUserChoice
        self.accessibilityName = accessibilityName
        self.page = page
        self.trailing = trailing
    }

    var body: some View {
        ZStack {
            // The carousel for VoiceOver and UI tests: one adjustable element over the whole
            // carousel. It takes no touches, so drags reach the scroll view underneath.
            Color.clear
                .frame(width: pageWidth, height: OptionsLayout.carouselHeight)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityValue(valueOverride ?? accessibilityName(selection))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: step(by: 1)
                    case .decrement: step(by: -1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier(identifier)
            scrollView
        }
        .frame(width: pageWidth, height: OptionsLayout.carouselHeight)
        .onChange(of: restingPage) { _, page in
            guard let page else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                position.scrollTo(id: page)
            }
        }
    }

    private var scrollView: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Option.allCases, id: \.self) { option in
                        page(option)
                            .frame(width: pageWidth, height: OptionsLayout.carouselHeight)
                            .id(option.rawValue)
                    }
                }
                .scrollTargetLayout()
                .accessibilityHidden(true)
                trailing()
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        // The pages are equal and the trailing slot adds no width, so page `i` of `n` rests at
        // `i / (n - 1)` of the scrollable range: this anchor puts the scroll view on the stored
        // page on its first layout and keeps it there if the content width changes later (the
        // first pass can come before the page width is known).
        .defaultScrollAnchor(startAnchor, for: .initialOffset)
        .defaultScrollAnchor(startAnchor, for: .sizeChanges)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.x }) { _, offset in
            lastOffset = offset
            if userDriven { select(forOffset: offset) }
        }
        .onScrollPhaseChange { _, phase in
            switch phase {
            case .interacting, .decelerating:
                userDriven = true
            case .idle:
                if userDriven {
                    select(forOffset: lastOffset)
                    onUserChoice(selection)
                }
                userDriven = false
            case .tracking, .animating:
                break
            @unknown default:
                break
            }
        }
        .frame(width: pageWidth, height: OptionsLayout.carouselHeight)
        .clipped()
    }

    /// Where the carousel rests: the photo's resting page, else the selected option's page.
    private var startAnchor: UnitPoint {
        let count = Option.allCases.count
        guard count > 1 else { return .leading }
        let page = min(max(restingPage ?? selection.rawValue, 0), count - 1)
        return UnitPoint(x: CGFloat(page) / CGFloat(count - 1), y: 0.5)
    }

    private func select(forOffset offset: CGFloat) {
        let index = CarouselPaging.page(forOffset: offset, pageWidth: pageWidth, count: Option.allCases.count)
        let option = Option.clamped(index)
        if option != selection { selection = option }
    }

    /// VoiceOver's swipe up/down: move one page and store it, clamped at the ends. From a
    /// resting page (the photo in use) it moves from that page and always counts as a choice.
    private func step(by delta: Int) {
        let base = restingPage ?? selection.rawValue
        let option = Option.clamped(base + delta)
        guard option != selection || restingPage != nil else { return }
        if option != selection { selection = option }
        onUserChoice(option)
        withAnimation(.easeInOut(duration: 0.3)) {
            position.scrollTo(id: option.rawValue)
        }
    }
}

extension OptionCarousel where Trailing == EmptyView {
    init(
        title: String,
        identifier: String,
        pageWidth: CGFloat,
        selection: Binding<Option>,
        accessibilityName: @escaping (Option) -> String,
        @ViewBuilder page: @escaping (Option) -> Page
    ) {
        self.init(
            title: title,
            identifier: identifier,
            pageWidth: pageWidth,
            selection: selection,
            accessibilityName: accessibilityName,
            page: page,
            trailing: { EmptyView() }
        )
    }
}

/// The page control under each carousel: one dot per option, the current one white
/// (standard white UIPageControl dots in the original; the dots are not tappable there either).
struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(index == current ? 1 : 0.35))
                    .frame(width: 6.5, height: 6.5)
            }
        }
        .accessibilityHidden(true)
    }
}
