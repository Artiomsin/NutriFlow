import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(icon: "house", title: "Home", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabBarButton(icon: "chart.bar.fill", title: "Progress", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            TabBarButton(icon: "gearshape", title: "Settings", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusTabBar)
    }
}
