//
//  AuthFactory.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import SwiftUI

enum AuthFactory {
    @MainActor
    static func make(container: AppDependency, coordinator: AppCoordinator) -> AuthScreen {
        AuthScreen(container: container, coordinator: coordinator)
    }
}
