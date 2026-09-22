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
    var tint: Color = AppColors.accent
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: AppSpacing.iconSize))
                .foregroundColor(tint)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding()
        .appGlassSurface(level: .inset)
    }
}
