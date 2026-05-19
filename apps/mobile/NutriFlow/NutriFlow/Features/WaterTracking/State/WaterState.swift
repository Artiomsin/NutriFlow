//
//  WaterState.swift
//  Nutriflow
//
//  Created by Artem on 19.05.26.
//

import Foundation

enum WaterState {

    case idle
    case loading

    case loaded([WaterEntry])

    case saving

    case error(Error)
}
