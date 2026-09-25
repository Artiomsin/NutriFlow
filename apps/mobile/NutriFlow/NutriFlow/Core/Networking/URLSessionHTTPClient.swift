import Foundation

final class URLSessionHTTPClient: HTTPClient, Sendable {
    private struct ErrorEnvelope: Decodable {
        let requestId: String?
    }

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

    func send<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws -> T {
        let (data, response) = try await execute(request, retryOn401: true)
        let validatedData = try validate(data: data, response: response)

        do {
            return try JSONDecoder().decode(T.self, from: validatedData)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func sendVoid<Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws {
        let (data, response) = try await execute(request, retryOn401: true)
        _ = try validate(data: data, response: response)
    }

    func sendUpload(
        data: Data,
        fileName: String,
        mimeType: String,
        path: String
    ) async throws -> String {
        struct UploadResponse: Codable {
            let url: String
        }

        let response: UploadResponse = try await sendMultipart(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            path: path
        )
        return response.url
    }

    func sendMultipart<T: Decodable & Sendable>(
        data: Data,
        fileName: String,
        mimeType: String,
        path: String
    ) async throws -> T {
        let (responseData, response) = try await executeMultipart(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            path: path,
            retryOn401: true
        )
        let validatedData = try validate(data: responseData, response: response)

        do {
            return try JSONDecoder().decode(T.self, from: validatedData)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func execute<Body: Encodable & Sendable>(
        _ request: APIRequest<Body>,
        retryOn401: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        let urlRequest = try buildURLRequest(from: request)
        let (data, response) = try await perform(urlRequest)

        if retryOn401,
           response.statusCode == 401,
           try await shouldRetryAfter401(path: request.path) {
            let result = try await execute(request, retryOn401: false)

            if result.1.statusCode == 401, let refreshService {
                await refreshService.invalidateSession()
            }

            return result
        }

        return (data, response)
    }

    private func executeMultipart(
        data: Data,
        fileName: String,
        mimeType: String,
        path: String,
        retryOn401: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        let boundary = UUID().uuidString

        guard let url = URL(string: APIConfig.baseURL + path) else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HTTPMethod.POST.rawValue
        urlRequest.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body

        let (responseData, response) = try await perform(urlRequest)

        if retryOn401,
           response.statusCode == 401,
           try await shouldRetryAfter401(path: path) {
            let result = try await executeMultipart(
                data: data,
                fileName: fileName,
                mimeType: mimeType,
                path: path,
                retryOn401: false
            )

            if result.1.statusCode == 401, let refreshService {
                await refreshService.invalidateSession()
            }

            return result
        }

        return (responseData, response)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.requestFailed
            }

            return (data, httpResponse)
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch let error as URLError {
            throw APIError.transport(code: error.code)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.unknown
        }
    }

    private func shouldRetryAfter401(path: String) async throws -> Bool {
        guard Self.shouldRefreshToken(for: path), let refreshService else {
            return false
        }

        try await refreshService.refresh()
        return true
    }

    private static func shouldRefreshToken(for path: String) -> Bool {
        switch path {
        case AuthEndpoints.register,
             AuthEndpoints.login,
             AuthEndpoints.refresh,
             AuthEndpoints.google,
             AuthEndpoints.apple:
            return false
        default:
            return true
        }
    }

    private func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        let requestId = requestId(from: data, response: response)

        switch response.statusCode {
        case 200...299:
            return data
        case 400, 422:
            throw APIError.invalidRequest(
                statusCode: response.statusCode,
                requestId: requestId
            )
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 408:
            throw APIError.requestTimeout(requestId: requestId)
        case 409:
            throw APIError.conflict(requestId: requestId)
        case 429:
            throw APIError.rateLimited(requestId: requestId)
        case 500...599:
            throw APIError.serverError(
                statusCode: response.statusCode,
                requestId: requestId
            )
        default:
            throw APIError.http(
                statusCode: response.statusCode,
                requestId: requestId
            )
        }
    }

    private func requestId(from data: Data, response: HTTPURLResponse) -> String? {
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data),
           let requestId = envelope.requestId {
            return requestId
        }

        return response.value(forHTTPHeaderField: "X-Request-ID")
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
            do {
                urlRequest.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.encodingFailed
            }
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return urlRequest
    }
}
