//
//  HomeViewModel.swift
//  Nutriflow
//

import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {

    let foodViewModel: FoodViewModel
    let waterViewModel: WaterViewModel
    let dailyViewModel: DailySummaryViewModel

    init(
        foodViewModel: FoodViewModel,
        waterViewModel: WaterViewModel,
        dailyViewModel: DailySummaryViewModel
    ) {
        self.foodViewModel = foodViewModel
        self.waterViewModel = waterViewModel
        self.dailyViewModel = dailyViewModel
    }

    func loadAll() async {
        async let daily: Void = dailyViewModel.loadToday()
        async let food: Void = foodViewModel.loadToday()
        async let water: Void = waterViewModel.loadToday()
        _ = await (daily, food, water)
    }

    func addFood() async {
        await foodViewModel.createFood()
        dailyViewModel.invalidateCache()
        await dailyViewModel.loadToday()
    }
    
    func deleteFood(id: String) async {
        await foodViewModel.deleteFood(id: id)
        dailyViewModel.invalidateCache()
        await dailyViewModel.loadToday()
    }

    func addWater() async {
        await waterViewModel.createWater()
        dailyViewModel.invalidateCache()
        await dailyViewModel.loadToday()
    }
    
    func deleteWater(id: String) async {
        await waterViewModel.deleteWater(id: id)
        dailyViewModel.invalidateCache()
        await dailyViewModel.loadToday()
    }
}
