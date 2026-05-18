import Foundation

final class UserService: UserServiceProtocol {

    private let client: HTTPClient

    init(client: HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    func createUser(
        email: String,
        password: String,
        firstName: String?,
        lastName: String?
    ) async throws -> User {

        let request = APIRequest(
            path: UserEndpoints.createUser,
            method: .POST,
            body: CreateUserRequest(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            ),
            headers: [:]
        )

        return try await client.send(request)
    }

    func getUsers(token: String) async throws -> [User] {

        let request = APIRequest(
            path: UserEndpoints.getUsers,
            method: .GET,
            body: nil as EmptyBody?,
            headers: [
                "Authorization": "Bearer \(token)"
            ]
        )

        return try await client.send(request)
    }

    func getMe(token: String) async throws -> User {

        let request = APIRequest(
            path: UserEndpoints.getMe,
            method: .GET,
            body: nil as EmptyBody?,
            headers: [
                "Authorization": "Bearer \(token)"
            ]
        )

        return try await client.send(request)
    }

    func updateMe(
        token: String,
        email: String?,
        password: String?,
        firstName: String?,
        lastName: String?
    ) async throws -> User {

        let request = APIRequest(
            path: UserEndpoints.updateMe,
            method: .PUT,
            body: UpdateUserRequest(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            ),
            headers: [
                "Authorization": "Bearer \(token)"
            ]
        )

        return try await client.send(request)
    }
}
