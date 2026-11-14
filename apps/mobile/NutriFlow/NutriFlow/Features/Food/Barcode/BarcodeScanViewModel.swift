import Foundation
import Observation

@MainActor
@Observable
final class BarcodeScanViewModel {

    enum State: Equatable {
        case preparing
        case scanning
        case lookingUp(barcode: String)
        case invalidBarcode
        case notFound(barcode: String)
        case permissionDenied
        case failed(AppError)
    }

    private(set) var state: State = .preparing
    private(set) var foundFood: CatalogFood?

    let scanner: any BarcodeScanning

    private let service: FoodServiceProtocol
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    private var isBusy = false

    init(
        scanner: any BarcodeScanning = BarcodeScannerService(),
        service: FoodServiceProtocol,
        analyticsTracker: AnalyticsTracking? = nil
    ) {
        self.scanner = scanner
        self.service = service
        self.analyticsTracker = analyticsTracker
    }

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "barcode_scan"))
    }

    func start() async {
        guard !isBusy, foundFood == nil else { return }

        isBusy = true
        defer {
            isBusy = false
            scanner.stop()
        }

        if scanner.state != .ready {
            state = .preparing
            await scanner.prepare()
        }

        switch scanner.state {
        case .denied:
            state = .permissionDenied
            return

        case .failed, .idle, .requestingPermission:
            state = .failed(.unknown)
            return

        case .ready:
            break
        }

        state = .scanning

        do {
            let barcode = try await scanner.scanOnce()
            await lookup(barcode)

        } catch BarcodeScannerError.cancelled {
            // Screen was dismissed while waiting for a code.

        } catch {
            let mapped = ErrorMapper.map(error)
            if mapped != .cancelled {
                state = .failed(mapped)
            }
        }
    }

    func scanAgain() {
        guard !isBusy else { return }
        scanTask?.cancel()
        foundFood = nil
        scanTask = Task { await start() }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        scanner.stop()
    }

    func toggleTorch() {
        scanner.toggleTorch()
    }

    private func lookup(_ barcode: String) async {
        state = .lookingUp(barcode: barcode)

        do {
            foundFood = try await service.getFoodByBarcode(barcode)

        } catch {
            if let apiError = error as? APIError {
                switch apiError.statusCode {
                case 400:
                    // Invalid GTIN / non-numeric / wrong length.
                    state = .invalidBarcode
                    return

                case 404:
                    // Valid GTIN, product is not in our catalog or OFF.
                    state = .notFound(barcode: barcode)
                    return

                default:
                    break
                }
            }

            let mapped = ErrorMapper.map(error)
            guard mapped != .cancelled else { return }

            // 503 service-unavailable, 429 rate-limited, offline, timeout.
            state = .failed(mapped)
        }
    }
}
