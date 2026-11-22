import SwiftUI
import Observation

@MainActor
@Observable
private final class ScrollTrackingState {
    // Scroll offsets change for every pixel moved. Keep them out of SwiftUI
    // observation so they do not invalidate the modifier's body while scrolling.
    @ObservationIgnored var lastOffset: CGFloat = 0
    @ObservationIgnored var toggleAnchor: CGFloat = 0
    @ObservationIgnored var lastSign = 0
    @ObservationIgnored var lastKnownMinimized = false
}

struct MinimizeTabBarModifier: ViewModifier {
    let tabBarState: TabBarState
    var isActive: () -> Bool = { true }

    @State private var scrollTracking = ScrollTrackingState()

    private let minimizeDistance: CGFloat = 30
    private let expandDistance: CGFloat = 80
    private let minScrollDistance: CGFloat = 30

    private struct ScrollInfo: Equatable {
        var offsetY: CGFloat
        var maxOffset: CGFloat
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: ScrollInfo.self, of: { geometry in
                ScrollInfo(
                    offsetY: geometry.contentOffset.y,
                    maxOffset: geometry.contentSize.height - geometry.containerSize.height
                )
            }) { oldValue, newValue in
                guard isActive() else { return }
                let newOffset = newValue.offsetY
                let maxOffset = newValue.maxOffset

                if tabBarState.isTabBarMinimized != scrollTracking.lastKnownMinimized {
                    scrollTracking.lastKnownMinimized = tabBarState.isTabBarMinimized
                    if !tabBarState.isTabBarMinimized {
                        scrollTracking.lastOffset = newOffset
                        scrollTracking.toggleAnchor = newOffset
                        scrollTracking.lastSign = 0
                    }
                }

                let delta = newOffset - scrollTracking.lastOffset
                scrollTracking.lastOffset = newOffset
                guard abs(delta) > 0.5 else { return }
                let sign = delta > 0 ? 1 : -1

                if sign != scrollTracking.lastSign {
                    scrollTracking.lastSign = sign
                    scrollTracking.toggleAnchor = newOffset
                }

                if tabBarState.isTabBarMinimized {
                    let liftedAboveBottom = maxOffset <= 0 || newOffset < maxOffset - expandDistance
                    if sign < 0, newOffset < scrollTracking.toggleAnchor - expandDistance, liftedAboveBottom {
                        tabBarState.isTabBarMinimized = false
                        scrollTracking.lastKnownMinimized = false
                        scrollTracking.lastSign = 0
                        scrollTracking.lastOffset = newOffset
                        scrollTracking.toggleAnchor = newOffset
                    }
                } else {
                    if sign > 0, newOffset > scrollTracking.toggleAnchor + minimizeDistance, newOffset > minScrollDistance {
                        tabBarState.isTabBarMinimized = true
                        scrollTracking.lastKnownMinimized = true
                        scrollTracking.lastSign = 0
                    }
                }
            }
    }
}

extension View {
    func minimizeTabBarOnScroll(
        tabBarState: TabBarState,
        isActive: @escaping () -> Bool = { true }
    ) -> some View {
        modifier(MinimizeTabBarModifier(tabBarState: tabBarState, isActive: isActive))
    }
}
