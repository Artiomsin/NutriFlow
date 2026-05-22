import Foundation
import Observation

@Observable
@MainActor
final class WaterViewModel {

    var state: WaterState = .idle
    var amountMl: String = ""
    
    @ObservationIgnored private let session: SessionManager
    @ObservationIgnored private let service: WaterTrackingServiceProtocol
    @ObservationIgnored var onUnauthorized: (() -> Void)?
    
    init(session: SessionManager, service: WaterTrackingServiceProtocol) {
        self.session = session
        self.service = service
    }
    
    func loadToday() async {
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        state = .loading

        do {
            let entries = try await service.getTodayWater(token: token)
            state = .loaded(entries)

        } catch let error as APIError {
            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
            }
            state = .error(error)

        } catch {
            state = .error(error)
        }
    }

    func createWater() async {
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        guard let ml = Int(amountMl) else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Количество должно быть числом"]))
            return
        }

        state = .saving

        do {
            _ = try await service.createWaterEntry(token: token, amountMl: ml)
            await loadToday()
            clearForm()

        } catch let error as APIError {
            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
            }
            state = .error(error)

        } catch {
            state = .error(error)
        }
    }

    func deleteWater(id: String) async {
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        do {
            _ = try await service.deleteWaterEntry(token: token, id: id)
            await loadToday()

        } catch let error as APIError {
            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
            }
            state = .error(error)

        } catch {
            state = .error(error)
        }
    }

    private func clearForm() {
        amountMl = ""
    }
    
    func setPreviewState(_ newState: WaterState) {
        state = newState
    }
}