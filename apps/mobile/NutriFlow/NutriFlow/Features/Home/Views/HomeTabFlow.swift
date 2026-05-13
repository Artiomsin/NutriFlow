//
//  HomeTabFlow.swift
//  Nutriflow
//
//  Created by Artem on 12.05.26.
//

import SwiftUI

struct HomeTabFlow: View {

    var body: some View {

        NavigationStack {
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
                .overlay(HomeTabView())
        }
    }
}
