import SwiftUI
import UIKit

/// A hue-only picker. The rendered gradient and the selected color share HSV coordinates.
struct GradientColorPicker: View {
    @Binding var selectedColor: Color

    @State private var hue: Double

    private let hueStops = stride(from: 0.0, through: 1.0, by: 0.125).map {
        Color(hue: $0, saturation: 1, brightness: 1)
    }

    init(selectedColor: Binding<Color>) {
        _selectedColor = selectedColor
        _hue = State(initialValue: Self.hue(from: selectedColor.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                LinearGradient(colors: hueStops, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 28)
                    .clipShape(.capsule)
                    .overlay {
                        Capsule()
                            .stroke(AppColors.border.opacity(0.7), lineWidth: 1)
                    }
                    .overlay {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Circle()
                                    .stroke(.white, lineWidth: 3)
                                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            }
                            .offset(x: thumbOffset(in: geometry.size.width))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateHue(value.location.x / max(geometry.size.width, 1))
                            }
                    )
            }
            .frame(height: 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Category color")
            .accessibilityValue(selectedColor.hexDescription)
            .accessibilityHint("Swipe up or down to adjust the hue.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    updateHue(hue + 0.05)
                case .decrement:
                    updateHue(hue - 0.05)
                @unknown default:
                    break
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(AppColors.border.opacity(0.7), lineWidth: 1))
                    .accessibilityHidden(true)

                Text(selectedColor.hexDescription)
                    .font(.caption.monospaced())
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .onChange(of: selectedColor) { _, newColor in
            hue = Self.hue(from: newColor)
        }
    }

    private func thumbOffset(in width: CGFloat) -> CGFloat {
        (hue - 0.5) * width
    }

    private func updateHue(_ value: Double) {
        hue = min(max(value, 0), 1)
        selectedColor = Color(hue: hue, saturation: 1, brightness: 1)
    }

    private static func hue(from color: Color) -> Double {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Double(hue)
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        switch hex.count {
        case 6:
            red = Double((int >> 16) & 0xFF) / 255
            green = Double((int >> 8) & 0xFF) / 255
            blue = Double(int & 0xFF) / 255
            alpha = 1
        case 8:
            red = Double((int >> 16) & 0xFF) / 255
            green = Double((int >> 8) & 0xFF) / 255
            blue = Double(int & 0xFF) / 255
            alpha = Double((int >> 24) & 0xFF) / 255
        default:
            return nil
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    fileprivate var hexDescription: String {
        toHex() ?? "Custom color"
    }
}

#Preview("Category color picker") {
    @Previewable @State var color = Color(hex: "#10B981") ?? .green

    VStack(alignment: .leading, spacing: 12) {
        Text("Color")
            .font(.headline)
        GradientColorPicker(selectedColor: $color)
    }
    .padding()
    .background(AppColors.background)
}
