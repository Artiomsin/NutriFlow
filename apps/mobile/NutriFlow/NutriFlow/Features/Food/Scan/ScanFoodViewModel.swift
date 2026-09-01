//
//  ScanFoodViewModel.swift
//  Nutriflow
//
//  Created by Artem on 28.08.2026.
//

import Foundation
import UIKit
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
           case failed(String)
       }


    private(set) var state: State = .idle
    private(set) var result: [FoodAnalysisItem] = []
    private(set) var capturedImageData: Data?

    private let foodService: FoodServiceProtocol
    let camera: CameraService

        init(
            camera: CameraService,
            foodService: FoodServiceProtocol
        ) {
            self.camera = camera
            self.foodService = foodService
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
                state = .failed(
                    "Camera access is denied. Allow camera access in Settings."
                )

            case .failed:
                state = .failed(
                    "Unable to configure the camera."
                )

            case .requestingPermission:
                state = .preparing

            case .idle:
                state = .failed(
                    "Camera is not ready."
                )
            }
        }
    
    func startCamera(){
        guard camera.state == .ready else
        {
            return
        }
        camera.start()
    }
    
    func stopCamera(){
        camera.stop()
    }
    
    func scan() async{
        guard state == .ready else{
            return
        }
        
        guard camera.state == .ready else {
                    state = .failed(
                        "Camera is not ready."
                    )
                    return
                }
        
        state = .capturing
        print("[ScanVM] shutter pressed → capturing")

        do{
            let image = try await camera.capturePhoto()
            print("[ScanVM] photo captured OK (\(image.size.width) x \(image.size.height))")
            
            state = .analyzing
            print("[ScanVM] sending photo to backend for analysis")
            
            try await analyze(image)
        }catch CameraService.CameraError.captureCancelled,
               CameraService.CameraError.captureTimeout {
           print("[ScanVM] capture cancelled/timeout → restarting camera")
           camera.start()
           state = .ready

       } catch let error as APIError {
           print("[ScanVM] backend failed: HTTP \(String(describing: error.analyzeStatusCode))")
            state = .failed(
                "Food analysis service is temporarily unavailable. Please try again later."
            )

        } catch {
            print("[ScanVM] capture FAILED: \(error.localizedDescription)")
            state = .failed(
                error.localizedDescription
            )
        }
        
    }
    
    
    private func analyze(_ image: UIImage) async throws {
            guard let raw = image.jpegData(compressionQuality: 0.9),
                  let data = ImageCompressor.optimizedJPEGData(
                    raw,
                    maxDimension: 1024,
                    quality: 0.85
                  ) else {
                print("[ScanVM] JPEG encoding FAILED")
                throw ScanError.imageEncodingFailed
            }
            capturedImageData = data
            print("[ScanVM] JPEG ready: \(data.count / 1024) KB (1024px, q0.85)")

            let analysis = try await foodService.analyzePhoto(data)
            print("[ScanVM] backend response OK: \(analysis.count) food(s) found")

            guard !analysis.isEmpty else {
                print("[ScanVM] backend returned empty list → notFound")
                state = .notFound
                return
            }

            result = analysis
            state = .completed
            print("[ScanVM] completed, storing result")
        }
    
    func reset() {
            result = []
            state = .idle
        }
    
    
    
    
    enum ScanError:  LocalizedError {
        case imageEncodingFailed
        var errorDescription: String? {
                    switch self {
                    case .imageEncodingFailed:
                        return "Unable to prepare the photo."
                    }
                }
    }

}
