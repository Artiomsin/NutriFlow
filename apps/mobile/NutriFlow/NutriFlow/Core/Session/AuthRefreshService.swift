//
//  AuthRefreshService.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import Foundation

enum AuthError: Error {
    case noSession
}

final class AuthRefreshService: Sendable {

    private let client: HTTPClient
    private let session: AuthSessionService

    init(client: HTTPClient, session: AuthSessionService) {
        self.client = client
        self.session = session
    }

    func refresh() async throws {
        guard let refresh = session.getRefreshToken() else {
            throw AuthError.noSession
        }

        let request = APIRequest(
            path: AuthEndpoints.refresh,
            method: .POST,
            body: RefreshDTO(refreshToken: refresh)
        )

        let response: AuthTokensResponse = try await client.send(request)

        session.saveSession(access: response.accessToken,
                            refresh: response.refreshToken)
    }
}
