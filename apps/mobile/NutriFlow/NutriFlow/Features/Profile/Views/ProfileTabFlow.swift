//
//  ProfileTabFlow.swift
//  Nutriflow
//
//  Created by Artem on 12.05.26.
//
import SwiftUI

struct ProfileTabFlow: View {

    @ObservedObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var session: SessionManager
    var onLogout: (() -> Void)?

    var body: some View {

        NavigationStack {
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
                .overlay(ProfileDisplayView(
                    viewModel: profileViewModel,
                    onLogout: onLogout
                ))
        }
    }
}
