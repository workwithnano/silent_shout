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

    @State private var position: ScrollPosition
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
        _position = State(initialValue: ScrollPosition(id: restingPage ?? selection.wrappedValue.rawValue))
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
        // The initial `ScrollPosition` is not always kept: a phase 5 UI run caught a relaunch
        // resting on page 0 instead of the stored page (the position was applied before the
        // pages had their full width, as far as can be told). So whenever the page width or the
        // content width changes, and on appearing, it is put back where it should rest, unless
        // the user is scrolling.
        .onChange(of: pageWidth) { _, _ in restoreRestingPosition() }
        .onAppear { restoreRestingPosition() }
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
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentSize.width }) { _, _ in
            restoreRestingPosition()
        }
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

    private func restoreRestingPosition() {
        guard !userDriven else { return }
        position.scrollTo(id: restingPage ?? selection.rawValue)
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
