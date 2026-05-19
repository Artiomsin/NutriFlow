import SwiftUI

struct HomeTabView: View {

    @EnvironmentObject var session: SessionManager
    @ObservedObject var viewModel: FoodViewModel

    @State private var showAddFood = false

    var body: some View {

        ScrollView(showsIndicators: false) {

            VStack(spacing: 24) {

                header

                FoodSection(
                    viewModel: viewModel,
                    onAddFood: {
                        showAddFood = true
                    }
                )
                .padding(.horizontal, AppTheme.paddingHorizontal)

                Spacer(minLength: 100)
            }
            .background(AppTheme.background)
        }
        .task {
            await viewModel.loadToday()
        }
        .fullScreenCover(isPresented: $showAddFood) {
            AddFoodView(viewModel: viewModel)
        }
    }

    private var header: some View {

        VStack(spacing: 6) {

            Text("Home")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, AppTheme.headerPaddingTop)

            Text("Your daily nutrition")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}
