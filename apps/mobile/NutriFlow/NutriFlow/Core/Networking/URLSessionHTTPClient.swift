import Foundation

final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession
    private let interceptors: [RequestInterceptor]
    private let refreshService: AuthRefreshService?

    init(
        interceptors: [RequestInterceptor] = [],
        refreshService: AuthRefreshService? = nil,
        configuration: URLSessionConfiguration = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            config.waitsForConnectivity = true
            return config
        }()
    ) {
        self.interceptors = interceptors
        self.refreshService = refreshService
        self.session = URLSession(configuration: configuration)
    }

    func send<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws -> T {
        var urlRequest = try buildURLRequest(from: request)

        for interceptor in interceptors {
            try await interceptor.adapt(&urlRequest)
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        if http.statusCode == 401,
           request.path != AuthEndpoints.refresh {
            try await refreshService?.refresh()
            return try await send(request)
        }

        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError(statusCode: http.statusCode)
        default:
            throw APIError.unknown
        }
    }

    func sendVoid<Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws {
        var urlRequest = try buildURLRequest(from: request)

        for interceptor in interceptors {
            try await interceptor.adapt(&urlRequest)
        }

        let (_, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        if http.statusCode == 401,
           request.path != AuthEndpoints.refresh {
            try await refreshService?.refresh()
            return try await sendVoid(request)
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError(statusCode: http.statusCode)
        default:
            throw APIError.unknown
        }
    }

    private func buildURLRequest<Body: Encodable & Sendable>(
        from request: APIRequest<Body>
    ) throws -> URLRequest {
        guard var components = URLComponents(string: APIConfig.baseURL + request.path) else {
            throw APIError.invalidURL
        }

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        request.headers.forEach {
            urlRequest.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        if let body = request.body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return urlRequest
    }
}
