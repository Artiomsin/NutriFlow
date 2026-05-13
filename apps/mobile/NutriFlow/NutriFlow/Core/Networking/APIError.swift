//
//  APIError.swift
//  Nutriflow
//
//  Created by Artem on 11.05.26.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed
    case unauthorized
    case forbidden
    case notFound
    case decodingFailed
    case serverError(statusCode: Int)
    case noData
    case unknown
}
