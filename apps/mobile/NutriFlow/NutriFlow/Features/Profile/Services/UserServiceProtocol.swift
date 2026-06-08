protocol UserServiceProtocol: Sendable {
    func createUser(
        email: String,
        password: String,
        firstName: String?,
        lastName: String?
    ) async throws -> User

    func getUsers() async throws -> [User]

    func getMe() async throws -> User

    func updateMe(
        email: String?,
        password: String?,
        firstName: String?,
        lastName: String?
    ) async throws -> User
}
