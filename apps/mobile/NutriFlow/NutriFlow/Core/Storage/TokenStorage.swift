//
//  TokenStorage.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import Foundation

protocol TokenStorage: Sendable {
    func getAccessToken() -> String?
    func getRefreshToken() -> String?

    func saveAccessToken(_ token: String)
    func saveRefreshToken(_ token: String)

    func clear()
}

final class KeychainTokenStorage: TokenStorage, @unchecked Sendable {

    private let keychain: KeychainService

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    func getAccessToken() -> String? {
        try? keychain.read("access_token")
    }

    func getRefreshToken() -> String? {
        try? keychain.read("refresh_token")
    }

    func saveAccessToken(_ token: String) {
        try? keychain.save(token, for: "access_token")
    }

    func saveRefreshToken(_ token: String) {
        try? keychain.save(token, for: "refresh_token")
    }

    func clear() {
        try? keychain.delete("access_token")
        try? keychain.delete("refresh_token")
    }
}
