//
//  ScanFoodViewModel.swift
//  Nutriflow
//
//  Created by Artem on 28.08.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ScanFoodViewModel {

    enum State: Equatable {
        case idle
        case preparing
        case ready
        case capturing
        case analyzing
        case completed
        case notFound
        case failed(AppError)
    }

    private(set) var state: State = .idle
    private(set) var result: [FoodAnalysisItem] = []
    private(set) var capturedImageData: Data?

    private let foodService: FoodServiceProtocol
    let camera: CameraService
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?

    init(
        camera: CameraService,
        foodService: FoodServiceProtocol,
        analyticsTracker: AnalyticsTracking? = nil
    ) {
        self.camera = camera
        self.foodService = foodService
        self.analyticsTracker = analyticsTracker
    }

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "scan_food"))
    }

    func prepareCamera() async {
        guard state != .preparing else { return }

        state = .preparing
        await camera.prepare()

        switch camera.state {
        case .ready:
            camera.start()
            state = .ready
        case .denied:
            state = .failed(.permissionDenied)
        case .requestingPermission:
            state = .preparing
        case .failed, .idle:
            state = .failed(.unknown)
        }
    }

    func startCamera() {
        guard camera.state == .ready else { return }
        camera.start()
    }

    func stopCamera() {
        camera.stop()
    }

    func scan() async {
        guard state == .ready, camera.state == .ready else {
            state = .failed(.unknown)
            return
        }

        state = .capturing

        do {
            let imageData = try await camera.capturePhoto()
            state = .analyzing
            try await analyze(imageData)
        } catch CameraService.CameraError.captureCancelled {
            camera.start()
            state = .ready
        } catch CameraService.CameraError.captureTimeout {
            state = .failed(.timeout)
        } catch {
            let mapped = ErrorMapper.map(error)
            guard mapped != .cancelled else {
                state = .ready
                camera.start()
                return
            }
            state = .failed(mapped)
        }
    }

    private func analyze(_ rawImageData: Data) async throws {
        let imageData = await Task.detached(priority: .userInitiated) {
            ImageCompressor.optimizedJPEGData(
                rawImageData,
                maxDimension: 1024,
                quality: 0.85
            )
        }.value

        guard let imageData else {
            throw ScanError.imageEncodingFailed
        }

        capturedImageData = imageData

        let analysis = try await foodService.analyzePhoto(imageData)

        guard !analysis.isEmpty else {
            state = .notFound
            return
        }

        result = analysis
        state = .completed
    }

    func reset() {
        result = []
        capturedImageData = nil
        state = .idle
    }

    enum ScanError: LocalizedError {
        case imageEncodingFailed

        var errorDescription: String? {
            switch self {
            case .imageEncodingFailed:
                "Unable to prepare the photo."
            }
        }
    }
}
