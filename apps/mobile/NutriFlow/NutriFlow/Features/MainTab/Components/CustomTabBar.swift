import SwiftUI

struct CustomTabBar: View {

    @Binding var selectedTab: Int

    @State private var isPressing = false
    @State private var highlightedTab: Int?

    private let tabs: [(icon: String, title: String)] = [
        ("house", "Home"),
        ("chart.bar.fill", "Progress"),
        ("gearshape", "Settings")
    ]

    private let horizontalPadding: CGFloat = 16

    var body: some View {

        GeometryReader { geometry in

            ZStack {

                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                .fill(.clear)
                .glassEffect(.clear)

                if isPressing,
                   let highlightedTab {

                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(.clear)
                    .glassEffect(.regular.interactive())
                    .frame(
                        width: lensWidth(
                            in: geometry.size.width
                        ),
                        height: 54
                    )
                    .position(
                        x: tabCenterX(
                            index: highlightedTab,
                            width: geometry.size.width
                        ),
                        y: geometry.size.height / 2
                    )
                    .allowsHitTesting(false)
                }

                HStack(spacing: 0) {

                    ForEach(
                        tabs.indices,
                        id: \.self
                    ) { index in

                        TabBarButton(
                            icon: tabs[index].icon,
                            title: tabs[index].title,
                            isSelected: selectedTab == index,
                            isHighlighted: highlightedTab == index
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in

                        let index = tabIndex(
                            at: value.location.x,
                            width: geometry.size.width
                        )

                        if !isPressing {

                            withAnimation(
                                .spring(
                                    response: 0.28,
                                    dampingFraction: 0.8
                                )
                            ) {
                                isPressing = true
                                highlightedTab = index
                            }

                        } else if highlightedTab != index {

                            withAnimation(
                                .spring(
                                    response: 0.24,
                                    dampingFraction: 0.78
                                )
                            ) {
                                highlightedTab = index
                            }
                        }
                    }
                    .onEnded { value in

                        let index = tabIndex(
                            at: value.location.x,
                            width: geometry.size.width
                        )

                        selectedTab = index
                        highlightedTab = nil
                        isPressing = false
                    }
            )
        }
        .frame(height: 68)
    }

    private func lensWidth(
        in totalWidth: CGFloat
    ) -> CGFloat {

        let contentWidth =
            totalWidth - horizontalPadding * 2

        let tabWidth =
            contentWidth / CGFloat(tabs.count)

        return min(tabWidth - 8, 62)
    }

    private func tabIndex(
        at x: CGFloat,
        width: CGFloat
    ) -> Int {

        let contentWidth =
            width - horizontalPadding * 2

        let tabWidth =
            contentWidth / CGFloat(tabs.count)

        let adjustedX =
            x - horizontalPadding

        let rawIndex =
            Int(floor(adjustedX / tabWidth))

        return min(
            max(rawIndex, 0),
            tabs.count - 1
        )
    }

    private func tabCenterX(
        index: Int,
        width: CGFloat
    ) -> CGFloat {

        let contentWidth =
            width - horizontalPadding * 2

        let tabWidth =
            contentWidth / CGFloat(tabs.count)

        return horizontalPadding
            + tabWidth * CGFloat(index)
            + tabWidth / 2
    }
}


