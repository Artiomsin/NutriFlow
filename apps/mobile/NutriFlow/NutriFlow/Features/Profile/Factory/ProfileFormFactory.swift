//
//  ProfileFormFactory.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import SwiftUI

enum ProfileFormFactory {
    @MainActor
    static func make(
        container: AppDependency,
        coordinator: AppCoordinator
    ) -> ProfileFormScreen {
        ProfileFormScreen(container: container, coordinator: coordinator)
    }
}
