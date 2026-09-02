import UIKit

enum ImageCompressor {

    /// Downscales (longest side <= maxDimension) and re-encodes to JPEG.
    /// Returns nil if the source can't be decoded or encoded.
    static func optimizedJPEGData(
        _ data: Data,
        maxDimension: CGFloat = 1024,
        quality: CGFloat = 0.7
    ) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let size = image.size
        let longestSide = max(size.width, size.height)
        if longestSide > maxDimension {
            let scale = maxDimension / longestSide
            let target = CGSize(
                width: max(1, (size.width * scale).rounded()),
                height: max(1, (size.height * scale).rounded())
            )
            guard let downscaled = image.preparingThumbnail(of: target) else { return nil }
            return downscaled.jpegData(compressionQuality: quality)
        }

        return image.jpegData(compressionQuality: quality)
    }
}