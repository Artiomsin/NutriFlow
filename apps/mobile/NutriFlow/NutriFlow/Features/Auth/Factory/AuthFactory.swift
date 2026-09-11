//
//  AuthFactory.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import SwiftUI

enum AuthFactory {
    @MainActor @ViewBuilder
    static func make(container: AppDependency, coordinator: AppCoordinator) -> some View {
        let viewModel = AuthViewModel(
            authService: container.authService,
            profileService: container.profileService,
            googleSignInService: container.googleSignInService,
            coordinator: coordinator,
            activitySync: container.activitySync
        )
        AuthView(viewModel: viewModel)
    }
}
