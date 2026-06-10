//
//  RequestInterceptor.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import Foundation

protocol RequestInterceptor: Sendable {
    func adapt(_ request: inout URLRequest) async throws
}
