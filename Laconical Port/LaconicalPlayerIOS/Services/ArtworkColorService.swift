import CoreImage
import Foundation
import SwiftUI
import UIKit

final class ArtworkColorService {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func dominantColor(for image: UIImage?) -> Color? {
        guard let image, let ciImage = CIImage(image: image) else { return nil }

        let extent = ciImage.extent
        guard !extent.isEmpty else { return nil }

        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

        guard let output = filter.outputImage else { return nil }

        var rgba = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &rgba,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return Color(
            red: Double(rgba[0]) / 255.0,
            green: Double(rgba[1]) / 255.0,
            blue: Double(rgba[2]) / 255.0,
            opacity: 1.0
        )
    }
}
