import Foundation
import Observation

@Observable
@MainActor
final class WaterViewModel {

    var state: WaterState = .idle
    var amountMl: String = ""
    
    @ObservationIgnored private let service: WaterTrackingServiceProtocol
    
    init(service: WaterTrackingServiceProtocol) {
        self.service = service
    }
    
    func loadToday() async {
        state = .loading

        do {
            let entries = try await service.getTodayWater()
            state = .loaded(entries)
        } catch {
            state = .error(error)
        }
    }

    func createWater() async {
        guard let ml = Int(amountMl) else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Количество должно быть числом"]))
            return
        }

        state = .saving

        do {
            try await service.createWaterEntry(amountMl: ml)
            AmplitudeService.shared.track(.waterAdded(amountMl: ml))
            await loadToday()
            clearForm()
        } catch {
            state = .error(error)
        }
    }

    func deleteWater(id: String) async {
        do {
            try await service.deleteWaterEntry(id: id)
            AmplitudeService.shared.track(.waterDeleted)
            await loadToday()
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
