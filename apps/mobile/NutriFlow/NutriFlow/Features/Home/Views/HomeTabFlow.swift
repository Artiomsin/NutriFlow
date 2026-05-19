import SwiftUI

struct HomeTabFlow: View {
    @ObservedObject var foodViewModel: FoodViewModel
    var body: some View {
        AppTheme.background.ignoresSafeArea()
            .overlay(
                            HomeTabView(viewModel: foodViewModel)
                        )
    }
}
