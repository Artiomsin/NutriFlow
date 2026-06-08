import Foundation

final class UserService: UserServiceProtocol, Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func createUser(email: String, password: String, firstName: String?, lastName: String?) async throws -> User {
        let request = APIRequest(
            path: UserEndpoints.createUser,
            method: .POST,
            body: CreateUserRequest(email: email, password: password, firstName: firstName, lastName: lastName)
        )

        return try await client.send(request)
    }

    func getUsers() async throws -> [User] {
        let request = APIRequest<NeverBody>(
            path: UserEndpoints.getUsers,
            method: .GET
        )

        return try await client.send(request)
    }

    func getMe() async throws -> User {
        let request = APIRequest<NeverBody>(
            path: UserEndpoints.getMe,
            method: .GET
        )

        return try await client.send(request)
    }

    func updateMe(email: String?, password: String?, firstName: String?, lastName: String?) async throws -> User {
        let request = APIRequest(
            path: UserEndpoints.updateMe,
            method: .PUT,
            body: UpdateUserRequest(email: email, password: password, firstName: firstName, lastName: lastName)
        )

        return try await client.send(request)
    }
}
