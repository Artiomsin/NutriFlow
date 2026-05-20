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
        await dailyViewModel.loadToday()
        await foodViewModel.loadToday()
        await waterViewModel.loadToday()
    }

    func addFood() async {
        await foodViewModel.createFood()
        await dailyViewModel.loadToday()
    }
    
    func deleteFood(id: String) async {
        await foodViewModel.deleteFood(id: id)
        await dailyViewModel.loadToday()
    }

    func addWater() async {
        await waterViewModel.createWater()
        await dailyViewModel.loadToday()
    }
    
    func deleteWater(id: String) async {
        await waterViewModel.deleteWater(id: id)
        await dailyViewModel.loadToday()
    }
}
