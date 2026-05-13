//
//  TabBarButton.swift
//  Nutriflow
//
//  Created by Artem on 12.05.26.
//
import SwiftUI

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .green : .white.opacity(0.4))
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .green : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
    }
}
