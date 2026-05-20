import SwiftUI

struct HomeTabView: View {

    @EnvironmentObject var session: SessionManager

    @ObservedObject var foodViewModel: FoodViewModel
    @ObservedObject var waterViewModel: WaterViewModel
    @ObservedObject var dailyViewModel: DailySummaryViewModel

    @State private var showAddFood = false
    @State private var showAddWater = false

    var body: some View {

        ScrollView(showsIndicators: false) {

            VStack(spacing: 24) {

                header

                DailySummarySection(viewModel: dailyViewModel)
                    .padding(.horizontal, AppTheme.paddingHorizontal)

                FoodSection(
                    viewModel: foodViewModel,
                    onAddFood: {
                        showAddFood = true
                    }
                )
                .padding(.horizontal, AppTheme.paddingHorizontal)

                WaterSection(
                    viewModel: waterViewModel,
                    onAddWater: {
                        showAddWater = true
                    }
                )
                .padding(.horizontal, AppTheme.paddingHorizontal)

                Spacer(minLength: 100)
            }
            .background(AppTheme.background)
        }
        .task {

            await dailyViewModel.loadToday()
            await foodViewModel.loadToday()
            await waterViewModel.loadToday()
        }
        .fullScreenCover(isPresented: $showAddFood) {

            AddFoodView(viewModel: foodViewModel)
        }
        .fullScreenCover(isPresented: $showAddWater) {

            AddWaterView(viewModel: waterViewModel)
        }
    }

    private var header: some View {

        VStack(spacing: 6) {

            Text("Home")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, AppTheme.headerPaddingTop)

            Text("Track your food and water intake")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}
