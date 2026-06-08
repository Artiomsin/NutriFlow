//
//  AuthSessionService.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import Foundation

final class AuthSessionService: Sendable {

    private let tokenStorage: TokenStorage

    init(tokenStorage: TokenStorage) {
        self.tokenStorage = tokenStorage
    }

    func getAccessToken() -> String? {
        tokenStorage.getAccessToken()
    }

    func getRefreshToken() -> String? {
        tokenStorage.getRefreshToken()
    }

    func saveSession(access: String, refresh: String) {
        tokenStorage.saveAccessToken(access)
        tokenStorage.saveRefreshToken(refresh)
    }

    func clear() {
        tokenStorage.clear()
    }

    func isLoggedIn() -> Bool {
        tokenStorage.getAccessToken() != nil
    }
}
