//
//  CustomTabBar.swift
//  Nutriflow
//
//  Created by Artem on 12.05.26.
//

import SwiftUI


struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(icon: "house", title: "Home", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabBarButton(icon: "person", title: "Profile", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            TabBarButton(icon: "gearshape", title: "Settings", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(red: 0.05, green: 0.06, blue: 0.08))
        .cornerRadius(20)
    }
}
