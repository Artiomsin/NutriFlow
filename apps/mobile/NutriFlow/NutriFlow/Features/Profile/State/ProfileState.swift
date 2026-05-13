//
//  ProfileState.swift
//  Nutriflow
//
//  Created by Artem on 11.05.26.
//

import Foundation

enum ProfileState {
    case loading
    case loaded(UserProfile)
    case empty
    case saving(UserProfile?)
    case error(Error)
}

