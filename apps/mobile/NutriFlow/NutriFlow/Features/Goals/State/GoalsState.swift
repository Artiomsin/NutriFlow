//
//  GoalsState.swift
//  Nutriflow
//
//  Created by Artem on 8.06.26.
//

import Foundation

enum GoalsState {
    case idle
    case loading
    case loaded(UserGoals)
    case error(Error)

}
