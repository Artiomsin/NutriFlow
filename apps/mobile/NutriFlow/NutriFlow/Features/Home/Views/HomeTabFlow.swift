import SwiftUI

struct HomeTabFlow: View {

    @Bindable var homeViewModel: HomeViewModel
    @Bindable var session: SessionManager

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            HomeTabView(session: session, homeViewModel: homeViewModel)
        }
    }
}
