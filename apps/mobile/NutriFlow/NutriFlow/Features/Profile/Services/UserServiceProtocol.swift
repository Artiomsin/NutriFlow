protocol UserServiceProtocol {
    func createUser(
        email: String,
        password: String,
        firstName: String?,
        lastName: String?
    ) async throws -> User

    func getUsers(token: String) async throws -> [User]

    func getMe(token: String) async throws -> User

    func updateMe(
        token: String,
        email: String?,
        password: String?,
        firstName: String?,
        lastName: String?
    ) async throws -> User
}
