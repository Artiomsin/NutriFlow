enum MediaEndpoints {
    static func catalogFile(named fileName: String) -> String {
        "/media/catalog/\(EndpointPath.component(fileName))"
    }
}
