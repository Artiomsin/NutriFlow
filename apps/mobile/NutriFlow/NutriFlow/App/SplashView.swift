//
//  SplashView.swift
//  Nutriflow
//
//  Created by Artem on 11.06.26.
//

import SwiftUI

struct SplashView: View {
    @State private var rotation = 0.0
    @State private var scale = 0.3
    @State private var iconOpacity = 0.0
    @State private var textOffset: CGFloat = 30
    @State private var textOpacity = 0.0

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer().frame(height: 230)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppTheme.accent)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)
                    .opacity(iconOpacity)

                Text("NutriFlow")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .offset(y: textOffset)
                    .opacity(textOpacity)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.6)) {
                rotation = 360
                scale = 1.0
                iconOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                textOffset = 0
                textOpacity = 1.0
            }
        }
    }
}

#Preview("Splash") {
    SplashView()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}
