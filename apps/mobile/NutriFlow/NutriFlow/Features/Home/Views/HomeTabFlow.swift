import SwiftUI

struct HomeTabFlow: View {

    var body: some View {
        AppTheme.background.ignoresSafeArea()
            .overlay(HomeTabView())
    }
}
