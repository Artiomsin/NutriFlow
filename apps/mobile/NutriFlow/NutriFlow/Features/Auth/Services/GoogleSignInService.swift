import Foundation
import UIKit
import GoogleSignIn

enum GoogleSignInError: LocalizedError {
    case noIdToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noIdToken: return "Failed to get Google ID token"
        case .cancelled: return "Sign in cancelled"
        }
    }
}

final class GoogleSignInService: Sendable {
    @MainActor
    func signIn() async throws -> String {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController
        else {
            throw GoogleSignInError.cancelled
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)

        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.noIdToken
        }

        return idToken
    }

    func restorePreviousSignIn() async throws -> String? {
        let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
        return user.idToken?.tokenString
    }

    @MainActor
    func disconnect() {
        GIDSignIn.sharedInstance.disconnect()
    }
}
