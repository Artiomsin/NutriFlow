//
//  SettingsRow.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//
import SwiftUI

struct SettingsRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: AppTheme.iconSize))
                .foregroundColor(AppTheme.accent)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}
