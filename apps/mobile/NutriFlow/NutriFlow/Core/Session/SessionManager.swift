import Foundation

enum SessionState {
    case idle
    case authenticated
    case unauthenticated
}

final class SessionManager: ObservableObject {

    @Published private(set) var state: SessionState = .idle
    
    private var tokenStorage: TokenStorageProtocol?

    convenience init() {
        self.init(tokenStorage: TokenStorage(keychain: KeychainService()))
    }

    init(tokenStorage: TokenStorageProtocol) {
        self.tokenStorage = tokenStorage
        check()
    }

    func setSession(accessToken: String, refreshToken: String) {
        do {
            try tokenStorage?.saveAccessToken(accessToken)
            try tokenStorage?.saveRefreshToken(refreshToken)
            state = .authenticated
        } catch {
            state = .unauthenticated
        }
    }

    func logout() {
        try? tokenStorage?.clear()
        state = .unauthenticated
    }

    func accessToken() -> String? {
        try? tokenStorage?.getAccessToken()
    }

    func refreshToken() -> String? {
        try? tokenStorage?.getRefreshToken()
    }

    private func check() {
        state = (try? tokenStorage?.getAccessToken()) != nil ? .authenticated : .unauthenticated
    }
}
