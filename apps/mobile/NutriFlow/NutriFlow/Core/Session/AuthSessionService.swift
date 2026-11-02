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

    /// Establishes a new user session. A new identifier is intentionally created
    /// for every completed sign-in, even for the same account.
    @discardableResult
    func establishSession(access: String, refresh: String) throws -> UUID {
        let sessionID = UUID()

        do {
            try tokenStorage.saveAccessToken(access)
            try tokenStorage.saveRefreshToken(refresh)
            try tokenStorage.saveSessionID(sessionID.uuidString)
            return sessionID
        } catch {
            try? tokenStorage.clear()
            throw error
        }
    }

    /// Updates credentials during token refresh without changing the image-cache namespace.
    func updateTokens(access: String, refresh: String) throws {
        do {
            try tokenStorage.saveAccessToken(access)
            try tokenStorage.saveRefreshToken(refresh)
        } catch {
            try? tokenStorage.clear()
            throw error
        }
    }

    /// Returns the current session identifier, migrating pre-session-ID Keychain
    /// records in place so existing signed-in people remain signed in.
    func sessionID() throws -> UUID? {
        if let storedID = try tokenStorage.getSessionID(),
           let sessionID = UUID(uuidString: storedID) {
            return sessionID
        }

        guard try tokenStorage.getAccessToken() != nil || tokenStorage.getRefreshToken() != nil else {
            return nil
        }

        let migratedID = UUID()
        try tokenStorage.saveSessionID(migratedID.uuidString)
        return migratedID
    }

    func clear() throws {
        try tokenStorage.clear()
    }

    func isLoggedIn() throws -> Bool {
        try tokenStorage.getAccessToken() != nil
    }
}
