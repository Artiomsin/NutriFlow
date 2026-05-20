import SwiftUI

struct HomeTabFlow: View {

    @ObservedObject var foodViewModel: FoodViewModel
    @ObservedObject var waterViewModel: WaterViewModel
    @ObservedObject var dailyViewModel: DailySummaryViewModel

    var body: some View {

        ZStack {

            AppTheme.background
                .ignoresSafeArea()

            HomeTabView(
                foodViewModel: foodViewModel,
                waterViewModel: waterViewModel,
                dailyViewModel: dailyViewModel
            )
        }
    }
}
