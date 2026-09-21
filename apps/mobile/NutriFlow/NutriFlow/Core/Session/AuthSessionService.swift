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

    func getAccessToken() throws -> String? {
        try tokenStorage.getAccessToken()
    }

    func getRefreshToken() throws -> String? {
        try tokenStorage.getRefreshToken()
    }

    func saveSession(access: String, refresh: String) throws {
        do {
            try tokenStorage.saveAccessToken(access)
            try tokenStorage.saveRefreshToken(refresh)
        } catch {
            try tokenStorage.clear()
            throw error
        }
    }

    func clear() throws {
        try tokenStorage.clear()
    }

    func isLoggedIn() throws -> Bool {
        try tokenStorage.getAccessToken() != nil
    }
}
