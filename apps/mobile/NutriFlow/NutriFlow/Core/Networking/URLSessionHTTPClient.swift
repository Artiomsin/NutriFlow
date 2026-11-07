
import Foundation
import OSLog

final class URLSessionHTTPClient: HTTPClient, Sendable {

    private let session: URLSession
    private let interceptors: [RequestInterceptor]
    private let refreshService: AuthRefreshService?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NutriFlow",
        category: "HTTPClient"
    )

    init(
        interceptors: [RequestInterceptor] = [],
        refreshService: AuthRefreshService? = nil,
        configuration: URLSessionConfiguration = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 60
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
        let (data, response) = try await execute(
            request,
            retryOn401: request.authenticationRetryPolicy == .afterTokenRefresh
        )

        let validatedData = try validate(data: data, response: response)

        do {
            return try JSONDecoder().decode(T.self, from: validatedData)
        } catch {
            #if DEBUG
            logger.error("""
            API DECODING ERROR
            Expected type: \(String(describing: T.self), privacy: .public)
            URL: \(response.url?.path ?? "unknown", privacy: .public)
            Status code: \(response.statusCode)
            Error: \(error.localizedDescription, privacy: .public)
            Response body: \(String(decoding: validatedData, as: UTF8.self), privacy: .private)
            """)
            #endif

            throw APIError.decodingFailed
        }
    }

    func sendVoid<Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws {
        let (data, response) = try await execute(
            request,
            retryOn401: request.authenticationRetryPolicy == .afterTokenRefresh
        )

        _ = try validate(data: data, response: response)
    }

    func sendUpload(
        data: Data,
        fileName: String,
        mimeType: String,
        path: String,
        authenticationRetryPolicy: AuthenticationRetryPolicy = .never
    ) async throws -> String {
        struct UploadResponse: Codable {
            let url: String
        }

        let response: UploadResponse = try await sendMultipart(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            path: path,
            authenticationRetryPolicy: authenticationRetryPolicy
        )

        return response.url
    }

    func sendMultipart<T: Decodable & Sendable>(
        data: Data,
        fileName: String,
        mimeType: String,
        path: String,
        authenticationRetryPolicy: AuthenticationRetryPolicy = .never
    ) async throws -> T {
        let (responseData, response) = try await executeMultipart(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            path: path,
            retryOn401: authenticationRetryPolicy == .afterTokenRefresh
        )

        let validatedData = try validate(data: responseData, response: response)

        do {
            return try JSONDecoder().decode(T.self, from: validatedData)
        } catch {
            #if DEBUG
            logger.error("""
            MULTIPART DECODING ERROR
            Expected type: \(String(describing: T.self), privacy: .public)
            URL: \(response.url?.path ?? "unknown", privacy: .public)
            Status code: \(response.statusCode)
            Error: \(error.localizedDescription, privacy: .public)
            Response body: \(String(decoding: validatedData, as: UTF8.self), privacy: .private)
            """)
            #endif

            throw APIError.decodingFailed
        }
    }

    private func execute<Body: Encodable & Sendable>(
        _ request: APIRequest<Body>,
        retryOn401: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        let urlRequest = try await buildURLRequest(from: request)

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
        let url = try makeURL(path: path)

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

        try await adapt(&urlRequest)

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

    private func perform(
        _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        let startedAt = Date()

        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url

        do {
            #if DEBUG
            logger.debug("""
            HTTP REQUEST
            Method: \(method, privacy: .public)
            URL: \(url?.absoluteString ?? "unknown", privacy: .public)
            """)
            #endif

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                logger.error("Invalid HTTP response")
                #endif
                throw APIError.requestFailed
            }

            let duration = Int(Date().timeIntervalSince(startedAt) * 1000)

            #if DEBUG
            let requestId = httpResponse.value(
                forHTTPHeaderField: "X-Request-ID"
            ) ?? "none"

            if (200...299).contains(httpResponse.statusCode) {
                logger.info("""
                HTTP RESPONSE
                Method: \(method, privacy: .public)
                URL: \(url?.absoluteString ?? "unknown", privacy: .public)
                Status: \(httpResponse.statusCode)
                Bytes: \(data.count)
                Duration: \(duration) ms
                Request ID: \(requestId, privacy: .public)
                """)
            } else {
                logger.error("""
                HTTP RESPONSE ERROR
                Method: \(method, privacy: .public)
                URL: \(url?.absoluteString ?? "unknown", privacy: .public)
                Status: \(httpResponse.statusCode)
                Bytes: \(data.count)
                Duration: \(duration) ms
                Request ID: \(requestId, privacy: .public)
                """)
            }
            #endif

            return (data, httpResponse)

        } catch is CancellationError {
            #if DEBUG
            logger.debug("Request cancelled: \(url?.path ?? "unknown", privacy: .public)")
            #endif

            throw Self.mapCancellation()

        } catch let error as URLError where error.code == .cancelled {
            #if DEBUG
            logger.debug("URL request cancelled: \(url?.path ?? "unknown", privacy: .public)")
            #endif

            throw Self.mapCancellation()

        } catch let error as URLError {
            #if DEBUG
            logger.error("""
            NETWORK ERROR
            URL: \(url?.path ?? "unknown", privacy: .public)
            Code: \(error.code.rawValue)
            Description: \(error.localizedDescription, privacy: .public)
            """)
            #endif

            throw APIError.transport(code: error.code)

        } catch let error as APIError {
            throw error

        } catch {
            #if DEBUG
            logger.error("""
            UNKNOWN HTTP ERROR
            URL: \(url?.path ?? "unknown", privacy: .public)
            Error: \(error.localizedDescription, privacy: .public)
            """)
            #endif

            throw APIError.unknown
        }
    }

    private static func mapCancellation() -> APIError {
        Task.isCancelled
            ? .cancelled
            : .transport(code: .networkConnectionLost)
    }

    private func shouldRetryAfter401(path: String) async throws -> Bool {
        guard Self.shouldRefreshToken(for: path),
              let refreshService else {
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

    private func validate(
        data: Data,
        response: HTTPURLResponse
    ) throws -> Data {
        if !(200...299).contains(response.statusCode),
           let problem = try? JSONDecoder().decode(ProblemDetails.self, from: data) {
            throw APIError.remote(
                problem,
                retryAfter: retryAfter(from: response)
            )
        }

        let requestId = response.value(forHTTPHeaderField: "X-Request-ID")

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

    private func retryAfter(
        from response: HTTPURLResponse
    ) -> TimeInterval? {
        guard let value = response.value(
            forHTTPHeaderField: "Retry-After"
        ) else {
            return nil
        }

        return TimeInterval(value)
    }

    private func buildURLRequest<Body: Encodable & Sendable>(
        from request: APIRequest<Body>
    ) async throws -> URLRequest {
        let url = try makeURL(
            path: request.path,
            queryItems: request.queryItems
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        request.headers.forEach {
            urlRequest.setValue(
                $0.value,
                forHTTPHeaderField: $0.key
            )
        }

        if let body = request.body {
            do {
                urlRequest.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.encodingFailed
            }

            urlRequest.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
        }

        try await adapt(&urlRequest)

        return urlRequest
    }

    private func adapt(_ request: inout URLRequest) async throws {
        for interceptor in interceptors {
            try await interceptor.adapt(&request)
        }
    }

    private func makeURL(
        path: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        guard var components = URLComponents(
            url: APIConfig.baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        let pathSuffix = path.hasPrefix("/")
            ? String(path.dropFirst())
            : path

        let basePath = components.percentEncodedPath.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )

        components.percentEncodedPath = "/" + [basePath, pathSuffix]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        return url
    }
}

