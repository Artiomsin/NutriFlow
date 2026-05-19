//
//  FoodState.swift
//  Nutriflow
//
//  Created by Artem on 19.05.26.
//

import Foundation

enum FoodState {

    case idle
    case loading
    case loaded([FoodEntry])
    case saving
    case error(Error)
}
