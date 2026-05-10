import Foundation

enum ProfileState: Equatable {
    case loading
    case loaded(UserProfile)
    case empty
    case saving(UserProfile?)
    case error(Error)
    
    static func == (lhs: ProfileState, rhs: ProfileState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.empty, .empty):
            return true
        case (.error, .error):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a.id == b.id
        case (.saving(let a), .saving(let b)):
            return a?.id == b?.id
        default:
            return false
        }
    }
}
