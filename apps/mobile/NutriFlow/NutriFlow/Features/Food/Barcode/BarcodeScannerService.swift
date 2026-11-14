import AVFoundation
import Observation

enum BarcodeScannerError: Error, Equatable, Sendable {
    case noCamera
    case notConfigured
    case sessionNotRunning
    case captureFailed
    case cancelled
}

protocol BarcodeScanning: AnyObject, Sendable {
    var session: AVCaptureSession { get }
    var state: BarcodeScannerService.State { get }
    var isTorchAvailable: Bool { get }
    var isTorchOn: Bool { get }

    func prepare() async
    func scanOnce() async throws -> String
    func stop()
    func toggleTorch()
}

@Observable
final class BarcodeScannerService: NSObject, BarcodeScanning, @unchecked Sendable {

    enum State: Equatable, Sendable {
        case idle
        case requestingPermission
        case ready
        case denied
        case failed
    }

    private(set) var state: State = .idle
    private(set) var isTorchOn = false
    private(set) var isTorchAvailable = false

    let session: AVCaptureSession

    private let sessionQueue = DispatchQueue(
        label: "com.nutriflow.barcode.session",
        qos: .userInitiated
    )

    private let metadataOutput: AVCaptureMetadataOutput

    // Access only from sessionQueue, together with AVCaptureSession.
    private var isConfigured = false
    private var device: AVCaptureDevice?

    @MainActor private var continuation: CheckedContinuation<String, Error>?

    private static let supportedTypes: Set<AVMetadataObject.ObjectType> = [
        .ean13,
        .ean8,
        .upce,
        .code128
    ]

    override init() {
        self.session = AVCaptureSession()
        self.metadataOutput = AVCaptureMetadataOutput()
        super.init()
    }

    func prepare() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break

        case .notDetermined:
            setState(.requestingPermission)
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                setState(.denied)
                return
            }

        case .denied, .restricted:
            setState(.denied)
            return

        @unknown default:
            setState(.denied)
            return
        }

        let outcome = await configureSession()
        setState(outcome)
    }

    @MainActor
    func scanOnce() async throws -> String {
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard self.continuation == nil else {
                    continuation.resume(throwing: BarcodeScannerError.captureFailed)
                    return
                }

                guard self.state == .ready else {
                    continuation.resume(throwing: BarcodeScannerError.notConfigured)
                    return
                }

                self.continuation = continuation
                self.start()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(.failure(BarcodeScannerError.cancelled))
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func toggleTorch() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.device, device.hasTorch else {
                return
            }

            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                let next: AVCaptureDevice.TorchMode =
                    device.torchMode == .on ? .off : .on

                guard device.isTorchModeSupported(next) else { return }
                device.torchMode = next

                let isOn = next == .on
                DispatchQueue.main.async { [weak self] in
                    self?.isTorchOn = isOn
                }
            } catch {
                // Torch is optional; scanning still works without it.
            }
        }
    }

    // MARK: - Private

    private func start() {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.session.isRunning else {
                return
            }
            self.session.startRunning()
        }
    }

    @MainActor
    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        stop()
        continuation.resume(with: result)
    }

    private func configureSession() async -> State {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: .failed)
                    return
                }

                guard !self.isConfigured else {
                    continuation.resume(returning: .ready)
                    return
                }

                guard let camera = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back
                ) else {
                    continuation.resume(returning: .failed)
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(device: camera)

                    self.session.beginConfiguration()
                    self.session.sessionPreset = .high

                    guard
                        self.session.canAddInput(input),
                        self.session.canAddOutput(self.metadataOutput)
                    else {
                        self.session.commitConfiguration()
                        continuation.resume(returning: .failed)
                        return
                    }

                    self.session.addInput(input)
                    self.session.addOutput(self.metadataOutput)

                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                    self.metadataOutput.metadataObjectTypes = self.metadataOutput
                        .availableMetadataObjectTypes
                        .filter(Self.supportedTypes.contains)

                    self.session.commitConfiguration()

                    self.device = camera
                    self.isConfigured = true

                    let hasTorch = camera.hasTorch
                    DispatchQueue.main.async { [weak self] in
                        self?.isTorchAvailable = hasTorch
                    }

                    continuation.resume(returning: .ready)
                } catch {
                    self.session.commitConfiguration()
                    continuation.resume(returning: .failed)
                }
            }
        }
    }

    private func setState(_ newState: State) {
        if Thread.isMainThread {
            state = newState
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.state = newState
            }
        }
    }
}

extension BarcodeScannerService: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let value = object.stringValue,
            !value.isEmpty
        else { return }

        let barcode = value

        Task { @MainActor [weak self] in
            self?.finish(.success(barcode))
        }
    }
}
