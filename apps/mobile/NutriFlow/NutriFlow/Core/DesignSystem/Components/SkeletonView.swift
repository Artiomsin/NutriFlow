import SwiftUI

struct SkeletonBlock: View {
    let width: CGFloat?
    let height: CGFloat
    var cornerRadius: CGFloat = 6

    init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = 6) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppColors.textSecondary.opacity(0.12))
            .frame(width: width, height: height)
    }
}

private struct SkeletonShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShimmering = false

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.10), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.55)
                        .offset(x: isShimmering ? geometry.size.width : -geometry.size.width)
                }
                .clipped()
                .allowsHitTesting(false)
            }
            .task(id: reduceMotion) {
                isShimmering = false
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    isShimmering = true
                }
            }
    }
}

extension View {
    func skeletonShimmer() -> some View {
        modifier(SkeletonShimmer())
    }
}
