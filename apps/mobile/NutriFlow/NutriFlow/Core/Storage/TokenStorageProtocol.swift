//
//  TokenStorageProtocol.swift
//  Nutriflow
//
//  Created by Artem on 12.05.26.
//

import Foundation

protocol TokenStorageProtocol {
    func saveAccessToken(_ token: String) throws
    func saveRefreshToken(_ token: String) throws
    func getAccessToken() throws -> String?
    func getRefreshToken() throws -> String?
    func clear() throws
}
