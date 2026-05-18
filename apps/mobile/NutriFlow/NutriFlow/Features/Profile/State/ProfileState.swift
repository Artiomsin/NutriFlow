import Foundation

enum ProfileState {
    case loading
    case loaded(UserProfile)
    case empty
    case saving(UserProfile?)
    case error(Error)
}

