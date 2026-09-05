//
//  ActivityEndpoints.swift
//  Nutriflow
//
//  Created by Artem on 03.09.2026.
//

import Foundation

enum ActivityEndpoints {
    static let sync = "/activity/sync"
    static let today = "/activity/today"

    static func range(from: String, to: String) -> (path: String, query: [URLQueryItem]) {
        (path: "/activity/range", query: [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ])
    }
}
