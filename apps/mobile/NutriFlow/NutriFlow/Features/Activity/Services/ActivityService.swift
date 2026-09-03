//
//  ActivityService.swift
//  Nutriflow
//
//  Created by Artem on 03.09.2026.
//

import Foundation

final class ActivityService: ActivityServiceProtocol, Sendable {
    
    private let client: HTTPClient
    
    init(client: HTTPClient){
        self.client = client
    }
    
    func sync(entries: [DailyActivity])async throws{
        
        let request = APIRequest(
            path: ActivityEndpoints.sync,
            method: .POST,
            body: ActivitySyncRequest(entries: entries)
        )
        try await client.sendVoid(request)
        
        
    }
}
