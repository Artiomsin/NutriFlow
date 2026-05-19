//
//  FoodService.swift
//  Nutriflow
//
//  Created by Artem on 18.05.26.
//

import Foundation


struct FoodService:FoodServiceProtocol {
    
    
    private let client: HTTPClient
    
    init(client: HTTPClient=URLSessionHTTPClient()) {
        self.client = client
    }
    
    func createFoodEntry(token: String, name: String, calories: Int, protein: Int?, fat: Int?, carbs: Int?) async throws -> FoodEntry {
        let request = APIRequest(
            path: FoodEndpoints.createFoodEntry,
            method: .POST,
            body: CreateFoodRequest(
                name: name,
                calories: calories,
                protein: protein,
                fat: fat,
                carbs: carbs
            ),
            headers: ["Authorization": "Bearer \(token)"]
            
        )
        return try await client.send(request)
    }
    
    func getTodayFood(token: String) async throws -> [FoodEntry] {
        let request=APIRequest(
            path: FoodEndpoints.getTodayFood,
            method: .GET,
            body: nil as EmptyBody?,
            headers: [
                "Authorization": "Bearer \(token)"
            ]
            
        )
        return try await client.send(request)
    }
    
    func deleteFoodEntry(token: String, id: String) async throws -> EmptyResponse {

            let request = APIRequest(
                path: FoodEndpoints.deleteFoodEntry(id: id),
                method: .DELETE,
                body: nil as EmptyBody?,
                headers: [
                    "Authorization": "Bearer \(token)"
                ]
            )

            return try await client.send(request)
        }
    
}
