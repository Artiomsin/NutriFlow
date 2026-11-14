import SwiftUI
import UIKit

struct BarcodeScanView: View {

    let onFound: (CatalogFood) -> Void

    @State private var viewModel: BarcodeScanViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(
        service: FoodServiceProtocol,
        analyticsTracker: AnalyticsTracking? = nil,
        onFound: @escaping (CatalogFood) -> Void
    ) {
        self.onFound = onFound
        _viewModel = State(
            initialValue: BarcodeScanViewModel(
                service: service,
                analyticsTracker: analyticsTracker
            )
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: viewModel.scanner.session)
                .ignoresSafeArea()

            scanWindow
            stateOverlay
        }
        .navigationTitle("Scan barcode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if viewModel.scanner.isTorchAvailable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.toggleTorch()
                    } label: {
                        Image(
                            systemName: viewModel.scanner.isTorchOn
                                ? "flashlight.on.fill"
                                : "flashlight.off.fill"
                        )
                    }
                    .tint(.white)
                }
            }
        }
        .task {
            viewModel.trackScreenView()
            await viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: viewModel.foundFood) { _, food in
            guard let food else { return }
            onFound(food)
        }
    }

    private var isLookingUp: Bool {
        if case .lookingUp = viewModel.state {
            return true
        }
        return false
    }

    private var scanWindow: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 64, 320)
            let height = width * 0.62

            let rect = CGRect(
                x: (proxy.size.width - width) / 2,
                y: (proxy.size.height - height) / 2,
                width: width,
                height: height
            )

            let lineHeight = max(rect.height - 20, 2)

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    path.addRoundedRect(
                        in: rect,
                        cornerSize: CGSize(width: 18, height: 18)
                    )
                }
                .fill(
                    Color.black.opacity(0.55),
                    style: FillStyle(eoFill: true)
                )

                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.9), lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                if viewModel.state == .scanning || isLookingUp {
                    ScanLine(travel: max(lineHeight - 2, 0))
                        .frame(
                            width: rect.width - 24,
                            height: lineHeight,
                            alignment: .top
                        )
                        .position(x: rect.midX, y: rect.midY)
                }

                if viewModel.state == .scanning {
                    Text("Point the camera at a barcode")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .position(x: rect.midX, y: rect.maxY + 34)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.state {
        case .preparing:
            statusCard(
                icon: "camera.fill",
                title: "Preparing camera",
                message: nil
            ) {
                ProgressView()
                    .tint(AppColors.accent)
            }

        case .scanning:
            EmptyView()

        case .lookingUp(let barcode):
            VStack {
                Spacer()

                HStack(spacing: 8) {
                    Text("Looking up")
                    Text(barcode)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(.bottom, 32)
            }

        case .invalidBarcode:
            statusCard(
                icon: "exclamationmark.triangle.fill",
                title: "Barcode not recognized",
                message: "Make sure the barcode is fully visible and try again."
            ) {
                actionButton("Scan again") {
                    viewModel.scanAgain()
                }
            }

        case .notFound(let barcode):
            statusCard(
                icon: "questionmark.circle.fill",
                title: "Product not found",
                message: "No product matches \(barcode). You can add it manually."
            ) {
                VStack(spacing: 10) {
                    actionButton("Scan again") {
                        viewModel.scanAgain()
                    }

                    secondaryButton("Add manually") {
                        dismiss()
                    }
                }
            }

        case .permissionDenied:
            statusCard(
                icon: "camera.fill",
                title: "Camera access denied",
                message: "Allow camera access in Settings to scan barcodes."
            ) {
                VStack(spacing: 10) {
                    actionButton("Open Settings") {
                        guard let url = URL(
                            string: UIApplication.openSettingsURLString
                        ) else { return }
                        openURL(url)
                    }

                    secondaryButton("Try again") {
                        viewModel.scanAgain()
                    }

                    secondaryButton("Cancel") {
                        dismiss()
                    }
                }
            }

        case .failed(let error):
            failureCard(error: error)
        }
    }

    private func failureCard(error: AppError) -> some View {
        let presentation = ErrorPresentation(error: error)

        return statusCard(
            icon: "exclamationmark.circle.fill",
            title: presentation.title,
            message: presentation.message
        ) {
            VStack(spacing: 10) {
                if presentation.allowsRetry {
                    actionButton("Try again") {
                        viewModel.scanAgain()
                    }
                }

                secondaryButton("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private func statusCard<Content: View>(
        icon: String,
        title: String,
        message: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppColors.accent)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            content()
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 300)
        .background(
            AppColors.background,
            in: RoundedRectangle(cornerRadius: AppRadius.large)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .padding(24)
    }

    private func actionButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    AppColors.accent,
                    in: RoundedRectangle(cornerRadius: AppRadius.medium)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

/// Sweeping indicator that keeps the scan window responsive while the lookup
/// is in flight, instead of a system spinner over the frozen camera frame.
private struct ScanLine: View {

    let travel: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, AppColors.accent, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .shadow(color: AppColors.accent.opacity(0.9), radius: 6)
            .offset(y: offset)
            .task {
                guard !reduceMotion, travel > 0 else { return }

                offset = 0
                withAnimation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                ) {
                    offset = travel
                }
            }
    }
}
