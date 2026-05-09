
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
        
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}
