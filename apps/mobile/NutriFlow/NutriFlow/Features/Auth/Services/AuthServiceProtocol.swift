import Foundation

protocol AuthServiceProtocol: Sendable {

    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async throws

    func login(
        email: String,
        password: String
    ) async throws

    func signInWithGoogle(idToken: String) async throws

    func logout() async throws

    func logoutAll() async throws
    
    func signInWithApple(identityToken: String, firstName: String?, lastName: String?) async throws
}
