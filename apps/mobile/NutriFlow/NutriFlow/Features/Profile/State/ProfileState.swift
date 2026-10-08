import Foundation

enum ProfileState {
    case loading
    case loaded(UserProfile)
    case empty
    case saving(UserProfile?)
    case error(AppError)

    var isSaving: Bool {
        if case .saving = self { return true }
        return false
    }
}

