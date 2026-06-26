import Foundation

final class StubUserService: UserServiceProtocol {
    func createUser(email: String, password: String, firstName: String?, lastName: String?) async throws -> User {
        throw GuestError.registrationRequired
    }

    func getUsers() async throws -> [User] {
        throw GuestError.operationNotAvailable
    }

    func getMe() async throws -> User {
        throw GuestError.registrationRequired
    }

    func updateMe(email: String?, password: String?, firstName: String?, lastName: String?) async throws -> User {
        throw GuestError.registrationRequired
    }
}
