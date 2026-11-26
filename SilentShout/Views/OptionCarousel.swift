import SwiftUI

/// One horizontal paging option carousel (SPEC.md section 3): one screen-wide page per option
/// with the option's art centred in it, starting on the stored option, and writing the option
/// back as the user scrolls, switching at 50% of the way to the next page.
///
/// `trailing` is laid out after the last page but is not a page: it never becomes the
/// selection and the page dots do not count it. Phase 5 uses it for the camera entry 1.0.1
/// appended to the texture carousel; until then it is empty.
struct OptionCarousel<Option: StoredOption & Hashable, Page: View, Trailing: View>: View {
    let title: String
    let identifier: String
    let pageWidth: CGFloat
    @Binding var selection: Option
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
        accessibilityName: @escaping (Option) -> String,
        @ViewBuilder page: @escaping (Option) -> Page,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.identifier = identifier
        self.pageWidth = pageWidth
        _selection = selection
        self.accessibilityName = accessibilityName
        self.page = page
        self.trailing = trailing
        _position = State(initialValue: ScrollPosition(id: selection.wrappedValue.rawValue))
    }

    var body: some View {
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
                trailing()
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
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
                if userDriven { select(forOffset: lastOffset) }
                userDriven = false
            case .tracking, .animating:
                break
            @unknown default:
                break
            }
        }
        .frame(width: pageWidth, height: OptionsLayout.carouselHeight)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityName(selection))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func select(forOffset offset: CGFloat) {
        let index = CarouselPaging.page(forOffset: offset, pageWidth: pageWidth, count: Option.allCases.count)
        let option = Option.clamped(index)
        if option != selection { selection = option }
    }

    /// VoiceOver's swipe up/down: move one page and store it, clamped at the ends.
    private func step(by delta: Int) {
        let option = Option.clamped(selection.rawValue + delta)
        guard option != selection else { return }
        selection = option
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
