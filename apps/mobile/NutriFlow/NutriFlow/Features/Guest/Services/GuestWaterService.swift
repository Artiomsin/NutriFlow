import Foundation

final class GuestWaterService: WaterTrackingServiceProtocol {
    private let store: GuestStore

    init(store: GuestStore) {
        self.store = store
    }

    func createWaterEntry(amountMl: Int, date: String? = nil) async throws -> WaterEntry {
        let entry = WaterEntry(amountMl: amountMl)
        store.addWater(entry)
        return entry
    }

    func getTodayWater() async throws -> [WaterEntry] {
        store.todayWater
    }

    func getWaterByDate(date: String) async throws -> [WaterEntry] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        return date == today ? store.todayWater : []
    }

    func deleteWaterEntry(id: String, date: String? = nil) async throws {
        store.removeWater(id: id)
    }
}
