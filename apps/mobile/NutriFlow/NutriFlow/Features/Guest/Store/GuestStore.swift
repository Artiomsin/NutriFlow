import Foundation

final class GuestStore: @unchecked Sendable {
    static let shared = GuestStore()

    private let defaults: UserDefaults
    private let key = "guest_data"
    private let queue = DispatchQueue(label: "com.nutriflow.gueststore")
    private var _data: GuestData

    var didShowExpiredWarning = false

    private init() {
        self.defaults = UserDefaults.standard
        if let saved = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(GuestData.self, from: saved) {
            self._data = decoded
            #if DEBUG
            if let json = String(data: saved, encoding: .utf8) {
                print("[GuestStore] loaded: \(json)")
            }
            #endif
        } else {
            self._data = .empty()
            print("[GuestStore] no data found, starting fresh")
        }
    }

    private func mutate<T>(_ block: (inout GuestData) -> T) -> T {
        queue.sync { block(&_data) }
    }

    var isExpired: Bool {
        let date = queue.sync { _data.date }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        return date != today
    }

    var todayDate: String {
        queue.sync { _data.date }
    }

    var todayFood: [FoodEntry] {
        queue.sync { _data.foodEntries }
    }

    var todayWater: [WaterEntry] {
        queue.sync { _data.waterEntries }
    }

    func addFood(_ entry: FoodEntry) {
        if isExpired { initializeNewDay() }
        mutate { $0.foodEntries.append(entry) }
        persist()
    }

    func addWater(_ entry: WaterEntry) {
        if isExpired { initializeNewDay() }
        mutate { $0.waterEntries.append(entry) }
        persist()
    }

    func removeFood(id: String) {
        mutate { $0.foodEntries.removeAll { $0.id == id } }
        persist()
    }

    func removeWater(id: String) {
        mutate { $0.waterEntries.removeAll { $0.id == id } }
        persist()
    }

    func initializeNewDay() {
        mutate { $0 = .empty() }
        didShowExpiredWarning = false
        persist()
    }

    func clear() {
        mutate { $0 = .empty() }
        didShowExpiredWarning = false
        persist()
    }

    func migrateToBackend(
        foodService: FoodServiceProtocol,
        waterService: WaterTrackingServiceProtocol
    ) async throws {
        let foods: [FoodEntry]
        let waters: [WaterEntry]
        (foods, waters) = queue.sync { (_data.foodEntries, _data.waterEntries) }

        print("[GuestStore] migrating \(foods.count) food, \(waters.count) water entries")
        for entry in foods {
            print("[GuestStore] POST food: \(entry.name) \(entry.calories)kcal")
            try await foodService.createFoodEntry(
                name: entry.name,
                calories: entry.calories,
                protein: entry.protein,
                fat: entry.fat,
                carbs: entry.carbs
            )
            print("[GuestStore] POST food OK: \(entry.name)")
        }
        for entry in waters {
            print("[GuestStore] POST water: \(entry.amountMl)ml")
            try await waterService.createWaterEntry(amountMl: entry.amountMl)
            print("[GuestStore] POST water OK: \(entry.amountMl)ml")
        }
        clear()
    }

    private func persist() {
        mutate { data in
            if let encoded = try? JSONEncoder().encode(data) {
                defaults.set(encoded, forKey: key)
                #if DEBUG
                if let json = String(data: encoded, encoding: .utf8) {
                    print("[GuestStore] saved: \(json)")
                }
                #endif
            }
        }
    }
}
