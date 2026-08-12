import SwiftUI

struct MinimizeTabBarModifier: ViewModifier {
    let tabBarState: TabBarState
    var isActive: () -> Bool = { true }

    @State private var lastOffset: CGFloat = 0
    @State private var toggleAnchor: CGFloat = 0
    @State private var lastSign: Int = 0
    @State private var lastKnownMinimized = false

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

                if tabBarState.isTabBarMinimized != lastKnownMinimized {
                    lastKnownMinimized = tabBarState.isTabBarMinimized
                    if !tabBarState.isTabBarMinimized {
                        lastOffset = newOffset
                        toggleAnchor = newOffset
                        lastSign = 0
                    }
                }

                let delta = newOffset - lastOffset
                lastOffset = newOffset
                guard abs(delta) > 0.5 else { return }
                let sign = delta > 0 ? 1 : -1

                if sign != lastSign {
                    lastSign = sign
                    toggleAnchor = newOffset
                }

                if tabBarState.isTabBarMinimized {
                    let liftedAboveBottom = maxOffset <= 0 || newOffset < maxOffset - expandDistance
                    if sign < 0, newOffset < toggleAnchor - expandDistance, liftedAboveBottom {
                        tabBarState.isTabBarMinimized = false
                        lastKnownMinimized = false
                        lastSign = 0
                        lastOffset = newOffset
                        toggleAnchor = newOffset
                    }
                } else {
                    if sign > 0, newOffset > toggleAnchor + minimizeDistance, newOffset > minScrollDistance {
                        tabBarState.isTabBarMinimized = true
                        lastKnownMinimized = true
                        lastSign = 0
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
