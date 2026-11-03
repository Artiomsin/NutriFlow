import Foundation

protocol TokenStorage: Sendable {
    func getAccessToken() throws -> String?
    func getRefreshToken() throws -> String?
    func getSessionID() throws -> String?

    func saveAccessToken(_ token: String) throws
    func saveRefreshToken(_ token: String) throws
    func saveSessionID(_ sessionID: String) throws

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

    func getSessionID() throws -> String? {
        try keychain.read("session_id")
    }

    func saveAccessToken(_ token: String) throws {
        try keychain.save(token, for: "access_token")
    }

    func saveRefreshToken(_ token: String) throws {
        try keychain.save(token, for: "refresh_token")
    }

    func saveSessionID(_ sessionID: String) throws {
        try keychain.save(sessionID, for: "session_id")
    }

    func clear() throws {
        try keychain.delete("access_token")
        try keychain.delete("refresh_token")
        try keychain.delete("session_id")
    }
}
