//
//  AddWaterView.swift
//  Nutriflow
//

import SwiftUI

struct AddWaterView: View {

    @Bindable var waterViewModel: WaterViewModel
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAmount = 250.0
    @State private var animatedAmount = 250.0

    @State private var animateSplash = false
    @State private var animateWave = false

    private let maxAmount: Double = 1000

    private let amounts = stride(
        from: 100,
        through: 1000,
        by: 50
    ).map(Double.init)

    var body: some View {

        VStack(spacing: 20) {

            header

            glassPreview

            amountPicker

            Spacer()

            saveButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            waterViewModel.amountMl = "\(Int(selectedAmount))"
            animatedAmount = selectedAmount
            animateWave = true
            AmplitudeService.shared.track(.screenView(screen: "add_water"))
        }
        .onChange(of: selectedAmount) { _, newValue in
            waterViewModel.amountMl = "\(Int(newValue))"
            triggerSplash()

            withAnimation(.easeInOut(duration: 0.45)) {
                animatedAmount = newValue
            }
        }
    }

    private var header: some View {

        HStack {
            Text("Water")
                .font(.title3.bold())
                .foregroundColor(.white)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private var glassPreview: some View {

        ZStack {

            GlassShape()
                .stroke(Color.white.opacity(0.18), lineWidth: 2)
                .background(
                    GlassShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.01)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .frame(width: 180, height: 270)

            ZStack {

                waterLayer
                waterSurface
                splashView

            }
            .clipShape(GlassShape(inset: 8))
            .frame(width: 180, height: 270)
        }
    }

    private var waterLayer: some View {

        GeometryReader { geo in

            let progress = animatedAmount / maxAmount
            let height = geo.size.height * progress

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.95),
                    Color.blue.opacity(0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var waterSurface: some View {

        GeometryReader { geo in

            let progress = animatedAmount / maxAmount
            let yOffset = geo.size.height * (1 - progress)

            ZStack {

                WaveShape(offset: animateWave ? 14 : -14)
                    .fill(Color.blue.opacity(0.75))

                WaveShape(offset: animateWave ? 10 : -10)
                    .fill(Color.cyan.opacity(0.55))
                    .offset(y: 6)
            }
            .frame(height: 28)
            .offset(y: yOffset - 14)
            .animation(
                .easeInOut(duration: 1.3)
                .repeatForever(autoreverses: true),
                value: animateWave
            )
        }
    }

    private var splashView: some View {

        ZStack {

            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 10, height: 10)
                .offset(x: -24, y: animateSplash ? -110 : -60)
                .opacity(animateSplash ? 0 : 1)

            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 7, height: 7)
                .offset(x: 10, y: animateSplash ? -120 : -70)
                .opacity(animateSplash ? 0 : 1)

            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 5, height: 5)
                .offset(x: 30, y: animateSplash ? -90 : -50)
                .opacity(animateSplash ? 0 : 1)
        }
        .animation(.easeOut(duration: 0.45), value: animateSplash)
    }

    private var amountPicker: some View {

        Picker("", selection: $selectedAmount) {

            ForEach(amounts, id: \.self) { amount in
                Text("\(Int(amount)) ml")
                    .foregroundColor(.white)
                    .tag(amount)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 130)
        .background(Color.white.opacity(0.08))
        .cornerRadius(22)
    }

    private var saveButton: some View {

        Button {

            Task {
                await waterViewModel.createWater()
                onSave()
                dismiss()
            }

        } label: {

            if case .saving = waterViewModel.state {
                ProgressView().tint(.black)
            } else {
                Text("Add Water")
                    .font(.headline)
                    .foregroundColor(.black)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.cyan)
        .cornerRadius(16)
    }

    private func triggerSplash() {

        animateSplash = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            animateSplash = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            animateSplash = false
        }
    }
}

#Preview {
    AddWaterViewPreview()
}

struct AddWaterViewPreview: View {
    var body: some View {
        let waterVM = WaterViewModel(
            service: MockWaterService()
        )

        AddWaterView(
            waterViewModel: waterVM,
            onSave: {}
        )
    }
}



struct GlassShape: Shape {

    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {

        let w = rect.width
        let h = rect.height

        let topWidth = w * 0.78
        let bottomWidth = w * 0.55

        let topX = (w - topWidth) / 2
        let bottomX = (w - bottomWidth) / 2

        var path = Path()

        path.move(to: CGPoint(x: topX + inset, y: inset))
        path.addLine(to: CGPoint(x: topX + topWidth - inset, y: inset))
        path.addLine(to: CGPoint(x: bottomX + bottomWidth - inset, y: h - inset))
        path.addLine(to: CGPoint(x: bottomX + inset, y: h - inset))
        path.closeSubpath()

        return path
    }
}



struct WaveShape: Shape {

    var offset: CGFloat

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {

        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.height / 2))

        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height / 2),
            control1: CGPoint(x: rect.width * 0.25, y: rect.height / 2 + offset),
            control2: CGPoint(x: rect.width * 0.75, y: rect.height / 2 - offset)
        )

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}
