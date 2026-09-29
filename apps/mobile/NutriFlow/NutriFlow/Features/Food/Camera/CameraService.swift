import AVFoundation
import Observation

@Observable
final class CameraService: NSObject, @unchecked Sendable {

    enum State: Equatable, Sendable {
        case idle
        case requestingPermission
        case ready
        case denied
        case failed
    }

    private(set) var state: State = .idle

    let session: AVCaptureSession

    private let sessionQueue = DispatchQueue(
        label: "com.nutriflow.camera.session",
        qos: .userInitiated
    )

    private let photoOutput: AVCapturePhotoOutput

    @MainActor private var photoContinuation: CheckedContinuation<Data, Error>?
    @MainActor private var captureTimeoutTask: Task<Void, Never>?

    // Access this flag only from sessionQueue, together with AVCaptureSession.
    private var isConfigured = false

    override init() {
        self.session = AVCaptureSession()
        self.photoOutput = AVCapturePhotoOutput()
        super.init()
    }

    func prepare() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            await configureSession()

        case .notDetermined:
            setState(.requestingPermission)
            let granted = await AVCaptureDevice.requestAccess(for: .video)

            if granted {
                await configureSession()
            } else {
                setState(.denied)
            }

        case .denied, .restricted:
            setState(.denied)

        @unknown default:
            setState(.denied)
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.session.isRunning else {
                return
            }

            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else {
                return
            }

            self.session.stopRunning()
        }
    }

    @MainActor
    func capturePhoto() async throws -> Data {
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard photoContinuation == nil else {
                    continuation.resume(throwing: CameraError.captureInProgress)
                    return
                }

                photoContinuation = continuation
                scheduleCaptureTimeout()

                sessionQueue.async { [weak self] in
                    guard let self else { return }

                    guard self.isConfigured else {
                        self.finishCaptureOnMain(with: .failure(CameraError.notConfigured))
                        return
                    }

                    guard self.session.isRunning else {
                        self.finishCaptureOnMain(with: .failure(CameraError.sessionNotRunning))
                        return
                    }

                    self.photoOutput.capturePhoto(
                        with: AVCapturePhotoSettings(),
                        delegate: self
                    )
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finishCapture(result: .failure(CameraError.captureCancelled))
            }
        }
    }

    private func configureSession() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                guard !self.isConfigured else {
                    self.setState(.ready)
                    continuation.resume()
                    return
                }

                guard let camera = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back
                ) else {
                    self.setState(.failed)
                    continuation.resume()
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(device: camera)

                    guard
                        self.session.canAddInput(input),
                        self.session.canAddOutput(self.photoOutput)
                    else {
                        self.setState(.failed)
                        continuation.resume()
                        return
                    }

                    self.session.beginConfiguration()
                    self.session.sessionPreset = .photo
                    self.session.addInput(input)
                    self.session.addOutput(self.photoOutput)
                    self.session.commitConfiguration()

                    self.isConfigured = true
                    self.setState(.ready)
                } catch {
                    self.setState(.failed)
                }

                continuation.resume()
            }
        }
    }

    private func setState(_ newState: State) {
        Task { @MainActor [weak self] in
            self?.state = newState
        }
    }

    private func finishCaptureOnMain(with result: Result<Data, Error>) {
        Task { @MainActor [weak self] in
            self?.finishCapture(result: result)
        }
    }

    @MainActor
    private func scheduleCaptureTimeout() {
        captureTimeoutTask?.cancel()
        captureTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(15))
            } catch {
                return
            }

            self?.finishCapture(result: .failure(CameraError.captureTimeout))
        }
    }

    enum CameraError: LocalizedError {
        case notConfigured
        case captureInProgress
        case sessionNotRunning
        case captureTimeout
        case captureCancelled
        case noImageData

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                "Camera is not configured."
            case .captureInProgress:
                "A photo capture is already in progress."
            case .sessionNotRunning:
                "Camera session is not running."
            case .captureTimeout:
                "Photo capture timed out. Try again."
            case .captureCancelled:
                "Photo capture was cancelled."
            case .noImageData:
                "Unable to read captured photo."
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            finishCaptureOnMain(with: .failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            finishCaptureOnMain(with: .failure(CameraError.noImageData))
            return
        }

        finishCaptureOnMain(with: .success(data))
    }
}

extension CameraService {

    @MainActor
    private func finishCapture(result: Result<Data, Error>) {
        guard let continuation = photoContinuation else {
            return
        }

        photoContinuation = nil
        captureTimeoutTask?.cancel()
        captureTimeoutTask = nil

        switch result {
        case .success(let data):
            continuation.resume(returning: data)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
