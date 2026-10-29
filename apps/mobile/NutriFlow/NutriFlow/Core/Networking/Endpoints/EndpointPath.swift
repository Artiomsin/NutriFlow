import Foundation

enum EndpointPath {
    private static let componentAllowedCharacters = CharacterSet.urlPathAllowed
        .subtracting(CharacterSet(charactersIn: "/"))

    static func component(_ value: String) -> String {
        value.addingPercentEncoding(
            withAllowedCharacters: componentAllowedCharacters
        ) ?? value
    }
}
