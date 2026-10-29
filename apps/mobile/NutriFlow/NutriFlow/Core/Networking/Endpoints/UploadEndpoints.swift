enum UploadEndpoints {
    static func uploadedImage(id: String) -> String {
        "/uploads/\(EndpointPath.component(id))"
    }
}
