

import Foundation

final class TokenStorage {
    
    static let shared = TokenStorage()
    private init() {}
    
    private let accessKey = "accessToken"
    private let refreshKey = "refreshToken"
    private let emailKey = "userEmail"
    private let firstNameKey = "userFirstName"
    private let lastNameKey = "userLastName"
    
    func save(access: String, refresh: String) {
        UserDefaults.standard.set(access, forKey: accessKey)
        UserDefaults.standard.set(refresh, forKey: refreshKey)
    }
    
    func saveUserData(email: String?, firstName: String?, lastName: String?) {
        if let email = email {
            UserDefaults.standard.set(email, forKey: emailKey)
        }
        if let firstName = firstName {
            UserDefaults.standard.set(firstName, forKey: firstNameKey)
        }
        if let lastName = lastName {
            UserDefaults.standard.set(lastName, forKey: lastNameKey)
        }
    }
    
    func getAccess() -> String? {
        UserDefaults.standard.string(forKey: accessKey)
    }
    
    func getRefresh() -> String? {
        UserDefaults.standard.string(forKey: refreshKey)
    }
    
    func getEmail() -> String? {
        UserDefaults.standard.string(forKey: emailKey)
    }
    
    func getFirstName() -> String? {
        UserDefaults.standard.string(forKey: firstNameKey)
    }
    
    func getLastName() -> String? {
        UserDefaults.standard.string(forKey: lastNameKey)
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: accessKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        UserDefaults.standard.removeObject(forKey: firstNameKey)
        UserDefaults.standard.removeObject(forKey: lastNameKey)
    }
}
