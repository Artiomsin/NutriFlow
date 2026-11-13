import SwiftUI
import UIKit

struct GradientColorPicker: View {
    @Binding var selectedColor: Color

    @State private var hue: Double

    private let presetColors: [Color] = [
        Color(hex: "#EF4444")!, Color(hex: "#DC2626")!,
        Color(hex: "#F97316")!, Color(hex: "#EA580C")!,
        Color(hex: "#F59E0B")!, Color(hex: "#D97706")!,
        Color(hex: "#EAB308")!, Color(hex: "#CA8A04")!,
        Color(hex: "#84CC16")!, Color(hex: "#65A30D")!,
        Color(hex: "#22C55E")!, Color(hex: "#16A34A")!,
        Color(hex: "#10B981")!, Color(hex: "#059669")!,
        Color(hex: "#14B8A6")!, Color(hex: "#0D9488")!,
        Color(hex: "#06B6D4")!, Color(hex: "#0891B2")!,
        Color(hex: "#0EA5E9")!, Color(hex: "#0284C7")!,
        Color(hex: "#3B82F6")!, Color(hex: "#2563EB")!,
        Color(hex: "#6366F1")!, Color(hex: "#4F46E5")!,
        Color(hex: "#8B5CF6")!, Color(hex: "#7C3AED")!,
        Color(hex: "#A855F7")!, Color(hex: "#9333EA")!,
        Color(hex: "#D946EF")!, Color(hex: "#C026D3")!,
        Color(hex: "#EC4899")!, Color(hex: "#DB2777")!
    ]

    private let hueStops = stride(
        from: 0.0,
        through: 1.0,
        by: 0.125
    ).map {
        Color(hue: $0, saturation: 1, brightness: 1)
    }

    init(selectedColor: Binding<Color>) {
        _selectedColor = selectedColor
        _hue = State(
            initialValue: Self.hue(from: selectedColor.wrappedValue)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Preset colors
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(
                        Array(presetColors.enumerated()),
                        id: \.offset
                    ) { _, color in
                        colorButton(color)
                    }
                }
                .padding(.vertical, 5)
                .padding(.trailing, 20)
            }
            .contentMargins(.trailing, -12, for: .scrollContent)

            // Hue gradient picker
            GeometryReader { geometry in
                LinearGradient(
                    colors: hueStops,
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 28)
                .clipShape(.capsule)
                .overlay {
                    Capsule()
                        .stroke(
                            AppColors.border.opacity(0.7),
                            lineWidth: 1
                        )
                }
                .overlay {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .shadow(
                                    color: .black.opacity(0.25),
                                    radius: 2,
                                    y: 1
                                )
                        }
                        .offset(
                            x: (hue - 0.5) * geometry.size.width
                        )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateHue(
                                value.location.x /
                                max(geometry.size.width, 1)
                            )
                        }
                )
            }
            .frame(height: 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Category color")
            .accessibilityValue(selectedColor.hexDescription)
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
        }
        .onChange(of: selectedColor) { _, newColor in
            hue = Self.hue(from: newColor)
        }
    }


    private func colorButton(_ color: Color) -> some View {
        let isSelected = color.toHex() == selectedColor.toHex()

        return Button {
            selectedColor = color
            hue = Self.hue(from: color)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay {
                    Circle()
                        .stroke(
                            isSelected ? .white : .clear,
                            lineWidth: 2
                        )
                        .padding(-3)
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.hexDescription)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }


    private func updateHue(_ value: Double) {
        hue = min(max(value, 0), 1)

        selectedColor = Color(
            hue: hue,
            saturation: 1,
            brightness: 1
        )
    }

    private static func hue(from color: Color) -> Double {
        let uiColor = UIColor(color)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        )

        return Double(hue)
    }
}


extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let normalized = value.hasPrefix("#")
            ? String(value.dropFirst())
            : value

        guard
            normalized.count == 6,
            normalized.allSatisfy(\.isHexDigit),
            let int = UInt64(normalized, radix: 16)
        else {
            return nil
        }

        self.init(
            .sRGB,
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255,
            opacity: 1
        )
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return nil
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }

    fileprivate var hexDescription: String {
        toHex() ?? "#000000"
    }
}

#Preview("Category color picker") {
    @Previewable @State var color = Color(hex: "#10B981") ?? .green

    VStack(alignment: .leading, spacing: 12) {
        Text("Category color")
            .font(.headline)

        GradientColorPicker(selectedColor: $color)
    }
    .padding()
    .background(AppColors.background)
}
