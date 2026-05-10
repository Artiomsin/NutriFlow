import Foundation

final class APIClient {
    
    static let shared = APIClient()
    private init() {}
    
    
    func request<T: Decodable>(
        endpoint: String,
        method: String,
        body: Data? = nil,
        token: String? = nil
    ) async throws -> T {
        
        print("[APIClient] Request: \(method) \(APIConfig.baseURL + endpoint)")
        
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            print("[APIClient] Invalid URL")
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token {
            print("[APIClient] Using token: \(token.prefix(10))...")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            print("[APIClient] Body: \(bodyString)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                print("[APIClient] Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("[APIClient] Response status: \(http.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("[APIClient] Response body: \(responseString)")
            }
            
            try checkStatus(http.statusCode, data: data)
            
            return try JSONDecoder().decode(T.self, from: data)
            
        } catch let error as APIError {
            print("[APIClient] API Error: \(error)")
            throw error
        } catch {
            print("[APIClient] Network Error: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    
    func requestVoid(
        endpoint: String,
        method: String,
        body: Data? = nil,
        token: String? = nil
    ) async throws {
        
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            try checkStatus(http.statusCode, data: data)
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    private func checkStatus(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200..<300:
            return
        case 400:
            let message = try? JSONDecoder().decode(ErrorResponse.self, from: data).message
            throw APIError.badRequest(message)
        case 401:
            throw APIError.unauthorized
        case 500..<600:
            throw APIError.serverError(statusCode)
        default:
            throw APIError.httpError(statusCode: statusCode, message: nil)
        }
    }
}

private struct ErrorResponse: Decodable {
    let message: String?
}