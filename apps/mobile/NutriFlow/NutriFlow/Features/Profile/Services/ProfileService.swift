
import Foundation


final class ProfileService {
    
    private let client = APIClient.shared
    
    func getMyProfile(token: String) async throws -> UserProfile {
           
           return try await client.request(
               endpoint: "/profiles/me",
               method: "GET",
               body: nil,
               token: token
           )
       }
    
    func createProfile(
            token: String,
            weight: Double?,
            height: Int?,
            age: Int?,
            goal: Goal?,
            activityLevel: ActivityLevel?
        ) async throws -> UserProfile {
            
            let body = try JSONEncoder().encode(
                CreateProfileRequest(
                    weight: weight,
                    height: height,
                    age: age,
                    goal: goal,
                    activityLevel: activityLevel
                )
            )
            
            return try await client.request(
                endpoint: "/profiles",
                method: "POST",
                body: body,
                token: token
            )
        }
    
    func updateMyProfile(
            token: String,
            weight: Double?,
            height: Int?,
            age: Int?,
            goal: Goal?,
            activityLevel: ActivityLevel?
        ) async throws -> UserProfile {
            
            let body = try JSONEncoder().encode(
                UpdateProfileRequest(
                    weight: weight,
                    height: height,
                    age: age,
                    goal: goal,
                    activityLevel: activityLevel
                )
            )
            
            return try await client.request(
                endpoint: "/profiles/me",
                method: "PUT",
                body: body,
                token: token
            )
        }
    
    func deleteMyProfile(token: String) async throws {
            
            try await client.requestVoid(
                endpoint: "/profiles/me",
                method: "DELETE",
                token: token
            )
        }
    
    
}
