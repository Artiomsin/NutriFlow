//
//  CategoryIconView.swift
//  Nutriflow
//
//  Created by Artem on 05.11.2026.
//

import SwiftUI

struct CategoryIconView: View {
    let iconName: String
    var color: Color = .primary

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}
