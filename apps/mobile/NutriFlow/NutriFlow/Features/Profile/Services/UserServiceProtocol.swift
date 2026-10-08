protocol UserServiceProtocol: Sendable {
    func getMe() async throws -> User

    func updateMe(
        email: String?,
        password: String?,
        firstName: String?,
        lastName: String?
    ) async throws -> User
}
