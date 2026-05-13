
final class TokenStorage: TokenStorageProtocol {

    private let keychain: KeychainService

    private let accessKey = "access_token"
    private let refreshKey = "refresh_token"

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    func saveAccessToken(_ token: String) throws {
        try keychain.save(token, for: accessKey)
    }

    func saveRefreshToken(_ token: String) throws {
        try keychain.save(token, for: refreshKey)
    }

    func getAccessToken() throws -> String? {
        try keychain.read(accessKey)
    }

    func getRefreshToken() throws -> String? {
        try keychain.read(refreshKey)
    }

    func clear() throws {
        try keychain.delete(accessKey)
        try keychain.delete(refreshKey)
    }
}
