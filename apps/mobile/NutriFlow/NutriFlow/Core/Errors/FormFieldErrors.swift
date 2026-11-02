import Foundation

/// Localized messages for individual form fields, keyed by their full API path.
/// Use the same full path for storage, lookup, and removal to avoid collisions
/// between fields such as `profile.weight` and `goal.weight`.
struct FormFieldErrors: Equatable, Sendable {
    private var messages: [String: String] = [:]

    var isEmpty: Bool {
        messages.isEmpty
    }

    subscript(field: String) -> String? {
        messages[field]
    }

    mutating func set(_ message: String, for field: String) {
        messages[field] = message
    }

    mutating func clear(_ field: String) {
        messages.removeValue(forKey: field)
    }

    mutating func removeAll() {
        messages.removeAll()
    }

    mutating func merge(_ other: FormFieldErrors) {
        messages.merge(other.messages) { _, new in new }
    }
}
