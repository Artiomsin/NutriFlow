//
//  ProfileFormFactory.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import SwiftUI

enum ProfileFormFactory {
    @MainActor @ViewBuilder
    static func make(container: AppDependency, coordinator: AppCoordinator) -> some View {
        let viewModel = ProfileViewModel(
            coordinator: coordinator,
            authService: container.authService,
            profileService: container.profileService,
            userService: container.userService,
            backgroundSyncer: container.backgroundSyncer
        )
        ProfileFormView(viewModel: viewModel)
    }
}
