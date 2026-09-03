//
//  ActivityState.swift
//  Nutriflow
//
//  Created by Artem on 03.09.2026.
//

import Foundation


enum ActivityState{
    case idle
    case needsAccess
    case denied
    case loading
    case loaded(DailyActivity)
    case error(Error)
}
