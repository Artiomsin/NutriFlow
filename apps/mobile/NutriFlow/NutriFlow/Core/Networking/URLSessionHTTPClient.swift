import Foundation

final class URLSessionHTTPClient: HTTPClient, Sendable {
    private let session: URLSession
    private let interceptors: [RequestInterceptor]
    private let refreshService: AuthRefreshService?

    init(
        interceptors: [RequestInterceptor] = [],
        refreshService: AuthRefreshService? = nil,
        configuration: URLSessionConfiguration = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 120
            config.timeoutIntervalForResource = 120
            config.waitsForConnectivity = true
            return config
        }()
    ) {
        self.interceptors = interceptors
        self.refreshService = refreshService
        self.session = URLSession(configuration: configuration)
    }

    private func shouldRetryAfter401<Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws -> Bool {
        guard request.path != AuthEndpoints.refresh else { return false }
        try await refreshService?.refresh()
        return true
    }

    func send<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws -> T {
        let (data, http) = try await execute(request, retryOn401: true)
        switch http.statusCode {
        case 200...299: return try JSONDecoder().decode(T.self, from: data)
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 404: throw APIError.notFound
        case 500...599: throw APIError.serverError(statusCode: http.statusCode)
        default: throw APIError.unknown
        }
    }

    func sendVoid<Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws {
        let (_, http) = try await execute(request, retryOn401: true)
        switch http.statusCode {
        case 200...299: return
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 404: throw APIError.notFound
        case 500...599: throw APIError.serverError(statusCode: http.statusCode)
        default: throw APIError.unknown
        }
    }

    private func execute<Body: Encodable & Sendable>(
        _ request: APIRequest<Body>,
        retryOn401: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        var urlRequest = try buildURLRequest(from: request)

        for interceptor in interceptors {
            try await interceptor.adapt(&urlRequest)
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        if retryOn401, http.statusCode == 401,
           try await shouldRetryAfter401(request) {
            return try await execute(request, retryOn401: false)
        }

        return (data, http)
    }

    func sendUpload(data: Data, fileName: String, mimeType: String, path: String) async throws -> String {
        struct UploadResponse: Codable { let url: String }
        let response: UploadResponse = try await sendMultipart(
            data: data, fileName: fileName, mimeType: mimeType, path: path
        )
        return response.url
    }

    func sendMultipart<T: Decodable & Sendable>(
        data: Data,
        fileName: String,
        mimeType: String,
        path: String
    ) async throws -> T {
        let (responseData, http) = try await executeMultipart(
            data: data, fileName: fileName, mimeType: mimeType, path: path, retryOn401: true
        )
        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: responseData)
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 404: throw APIError.notFound
        case 500...599: throw APIError.serverError(statusCode: http.statusCode)
        default: throw APIError.unknown
        }
    }

    private func executeMultipart(
        data: Data, fileName: String, mimeType: String, path: String, retryOn401: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        let boundary = UUID().uuidString

        guard let url = URL(string: APIConfig.baseURL + path) else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body

        for interceptor in interceptors {
            try await interceptor.adapt(&urlRequest)
        }

        let (responseData, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        if retryOn401, http.statusCode == 401, path != AuthEndpoints.refresh {
            try await refreshService?.refresh()
            return try await executeMultipart(data: data, fileName: fileName, mimeType: mimeType, path: path, retryOn401: false)
        }

        return (responseData, http)
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
