//
//  TokenStorage.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import Foundation

protocol TokenStorage: Sendable {
    func getAccessToken() throws -> String?
    func getRefreshToken() throws -> String?

    func saveAccessToken(_ token: String) throws
    func saveRefreshToken(_ token: String) throws

    func clear() throws
}

final class KeychainTokenStorage: TokenStorage, @unchecked Sendable {

    private let keychain: KeychainService

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    func getAccessToken() throws -> String? {
        try keychain.read("access_token")
    }

    func getRefreshToken() throws -> String? {
        try keychain.read("refresh_token")
    }

    func saveAccessToken(_ token: String) throws {
        try keychain.save(token, for: "access_token")
    }

    func saveRefreshToken(_ token: String) throws {
        try keychain.save(token, for: "refresh_token")
    }

    func clear() throws {
        try keychain.delete("access_token")
        try keychain.delete("refresh_token")
    }
}
