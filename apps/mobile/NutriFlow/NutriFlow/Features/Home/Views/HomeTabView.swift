//
//  HomeTabView.swift
//  Nutriflow
//
//  Created by Artem on 12.05.26.
//

import SwiftUI


struct HomeTabView: View {
    
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                
                VStack(spacing: 6) {
                    
                    Text("Home")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 60)
                    
                    Text("Welcome back")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                    .frame(height: 20)
                
                VStack(spacing: 16) {
                    
                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Your nutrition overview will appear here")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Progress")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Track your daily goals")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                    .frame(height: 100)
            }
        }
    }
}
