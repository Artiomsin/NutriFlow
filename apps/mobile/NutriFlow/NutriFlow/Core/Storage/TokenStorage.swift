

import Foundation

final class TokenStorage {
    
    static let shared = TokenStorage()
    private init() {}
    
    private let accessKey = "accessToken"
    private let refreshKey = "refreshToken"
    
    func save(access: String, refresh: String) {
        UserDefaults.standard.set(access, forKey: accessKey)
        UserDefaults.standard.set(refresh, forKey: refreshKey)
    }
    
    func getAccess() -> String? {
        UserDefaults.standard.string(forKey: accessKey)
    }
    
    func getRefresh() -> String? {
        UserDefaults.standard.string(forKey: refreshKey)
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: accessKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
    }
}
