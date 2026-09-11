import AVFoundation
import UIKit
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

    private var photoContinuation:
        CheckedContinuation<UIImage, Error>?

    private var isConfigured = false

    override init() {
        let session = AVCaptureSession()
        let photoOutput = AVCapturePhotoOutput()

        self.session = session
        self.photoOutput = photoOutput

        super.init()
    }


    func prepare() async {
        guard !isConfigured else {
            if state == .idle {
                setState(.ready)
            }
            return
        }

        print("[Camera] preparing (not configured)")

        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            print("[Camera] permission already granted")
            await configureSession()

        case .notDetermined:
            setState(.requestingPermission)
            print("[Camera] requesting camera permission")

            let granted = await AVCaptureDevice.requestAccess(
                for: .video
            )

            if granted {
                print("[Camera] permission granted")
                await configureSession()
            } else {
                print("[Camera] permission denied")
                setState(.denied)
            }

        case .denied, .restricted:
            print("[Camera] permission denied (previously)")
            setState(.denied)

        @unknown default:
            setState(.denied)
        }
    }


    func start() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard self.isConfigured else {
                print("[Camera] start ignored: not configured")
                return
            }

            guard !self.session.isRunning else {
                print("[Camera] start ignored: already running")
                return
            }

            print("[Camera] session startRunning")
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard self.session.isRunning else {
                print("[Camera] stop ignored: not running")
                return
            }

            print("[Camera] session stopRunning")
            self.session.stopRunning()
        }
    }


    func capturePhoto() async throws -> UIImage {
        guard isConfigured else {
            print("[Camera] capturePhoto FAILED: not configured")
            throw CameraError.notConfigured
        }

        guard session.isRunning else {
            print("[Camera] capturePhoto FAILED: session not running")
            throw CameraError.sessionNotRunning
        }

        try Task.checkCancellation()

        print("[Camera] capturePhoto started")

        return try await withThrowingTaskGroup(of: UIImage.self) { group in

            group.addTask { [self] in
                try await withTaskCancellationHandler {

                    try await withCheckedThrowingContinuation { continuation in
                        guard photoContinuation == nil else {
                            continuation.resume(
                                throwing: CameraError.captureInProgress
                            )
                            return
                        }

                        photoContinuation = continuation

                        photoOutput.capturePhoto(
                            with: AVCapturePhotoSettings(),
                            delegate: self
                        )
                    }

                } onCancel: { @Sendable in
                    Task { @MainActor [weak self] in
                        self?.finishCapture(
                            result: .failure(CameraError.captureCancelled)
                        )
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw CameraError.captureTimeout
            }

            guard let result = try await group.next() else {
                group.cancelAll()
                throw CameraError.captureTimeout
            }

            group.cancelAll()

            return result
        }
    }


    private func configureSession() async {
        guard !isConfigured else {
            return
        }

        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                guard !self.isConfigured else {
                    continuation.resume()
                    return
                }

                guard let camera = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back
                ) else {
                    self.finishConfiguration(success: false)
                    continuation.resume()
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(
                        device: camera
                    )

                    guard
                        self.session.canAddInput(input),
                        self.session.canAddOutput(self.photoOutput)
                    else {
                        self.finishConfiguration(success: false)
                        continuation.resume()
                        return
                    }

                    self.session.beginConfiguration()

                    self.session.sessionPreset = .photo

                    self.session.addInput(input)
                    self.session.addOutput(self.photoOutput)

                    self.session.commitConfiguration()

                    self.isConfigured = true

                    self.finishConfiguration(success: true)

                } catch {
                    self.finishConfiguration(success: false)
                }

                continuation.resume()
            }
        }
    }

    private func finishConfiguration(success: Bool) {
        setState(success ? .ready : .failed)
    }


    private func setState(_ newState: State) {
        Task { @MainActor [weak self] in
            self?.state = newState
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
            print("[Camera] photo delegate error: \(error.localizedDescription)")
            Task { @MainActor [weak self] in
                self?.finishCapture(
                    result: .failure(error)
                )
            }

            return
        }

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            print("[Camera] photo delegate: no image data")
            Task { @MainActor [weak self] in
                self?.finishCapture(
                    result: .failure(
                        CameraError.noImageData
                    )
                )
            }

            return
        }

        print("[Camera] photo delegate: got image (\(data.count / 1024) KB)")

        Task { @MainActor [weak self] in
            self?.finishCapture(
                result: .success(image)
            )
        }
    }
}


extension CameraService {

    @MainActor
    private func finishCapture(
        result: Result<UIImage, Error>
    ) {
        guard let continuation = photoContinuation else {
            return
        }

        photoContinuation = nil

        switch result {
        case .success(let image):
            continuation.resume(returning: image)

        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}