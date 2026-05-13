//
//  AuthState.swift
//  Nutriflow
//
//  Created by Artem on 11.05.26.
//

import Foundation

enum AuthState {
    case idle
    case loading
    case authenticated
    case unauthenticated
    case error(String)
}
