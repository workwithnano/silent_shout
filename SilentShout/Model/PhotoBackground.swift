import Foundation
import UIKit

/// Where the camera background lives: one JPEG in Application Support (phase 5, SPEC.md
/// section 9, "Rewrite additions"). Only one photo is kept; choosing a new one replaces it.
/// The photo stays stored when the user swipes back to a paper texture, so "Use Last Photo"
/// can bring it back.
struct PhotoBackgroundStore: Sendable {
    /// The folder holding the photo. Created on the first save.
    let directory: URL

    static let fileName = "background-photo.jpg"
    /// JPEG quality for the stored photo: no visible loss at full-screen size.
    static let jpegQuality: CGFloat = 0.9

    /// `Application Support/Background/` in the app's container.
    static var standard: PhotoBackgroundStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return PhotoBackgroundStore(directory: support.appending(path: "Background", directoryHint: .isDirectory))
    }

    var fileURL: URL { directory.appending(path: Self.fileName, directoryHint: .notDirectory) }

    var hasPhoto: Bool { FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) }

    /// Writes `image` (already normalised and downscaled, see `PhotoProcessing`) and returns it
    /// as a background with a stable id for this file.
    @discardableResult
    func save(_ image: UIImage) throws -> ShoutBackground {
        guard let data = image.jpegData(compressionQuality: Self.jpegQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        guard let saved = load() else { throw CocoaError(.fileReadCorruptFile) }
        return saved
    }

    /// The stored photo, or nil when there is none (or it cannot be read).
    func load() -> ShoutBackground? {
        guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else { return nil }
        return ShoutBackground(id: Self.id(for: data), image: image)
    }

    func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Same file contents, same id (within one run: `Hasher` is seeded per process); a new
    /// photo, a new id, so the shout's image cache redraws.
    static func id(for data: Data) -> String {
        var hasher = Hasher()
        hasher.combine(data.count)
        hasher.combine(data.prefix(4096))
        hasher.combine(data.suffix(4096))
        return "photo-\(data.count)-\(UInt(bitPattern: hasher.finalize()))"
    }
}

/// Getting a picked or captured photo ready to be a background: drawn upright (camera photos
/// carry their rotation as EXIF orientation) and no bigger than the screen needs.
enum PhotoProcessing {
    /// The pixel size to store `pixelSize` at: scaled down uniformly so its longest edge is at
    /// most `maxPixelLength`, never scaled up, rounded to whole pixels (at least 1).
    static func targetPixelSize(for pixelSize: CGSize, maxPixelLength: CGFloat) -> CGSize {
        guard pixelSize.width > 0, pixelSize.height > 0, maxPixelLength > 0 else { return .zero }
        let longest = max(pixelSize.width, pixelSize.height)
        let factor = min(1, maxPixelLength / longest)
        return CGSize(
            width: max((pixelSize.width * factor).rounded(), 1),
            height: max((pixelSize.height * factor).rounded(), 1)
        )
    }

    /// `image` redrawn upright (`imageOrientation == .up`) at scale 1, its longest edge at most
    /// `maxPixelLength` pixels. `UIImage.draw` applies the EXIF orientation.
    static func prepared(_ image: UIImage, maxPixelLength: CGFloat) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let target = targetPixelSize(for: pixelSize, maxPixelLength: maxPixelLength)
        guard target.width > 0, target.height > 0 else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// The longest screen edge in pixels: enough for an aspect-filled full-screen background.
    @MainActor
    static func maxPixelLength(screenSize: CGSize, scale: CGFloat) -> CGFloat {
        max(screenSize.width, screenSize.height) * scale
    }
}

#if DEBUG
/// A photo the app draws for UI tests (`-UITestPhotoFixture`), so they never drive the system
/// picker: a blue-to-violet gradient with lighter rings, 2000x3000 pixels stored with EXIF-style
/// orientation `.right`, so it shows as a 3000x2000 landscape picture and exercises the
/// orientation normalisation like a real camera photo. Every pixel is clearly blue, which the
/// UI tests sample to tell it from the paper textures.
enum PhotoFixture {
    static let launchArgument = "-UITestPhotoFixture"

    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    static func make() -> UIImage {
        let size = CGSize(width: 2000, height: 3000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let colors = [
                UIColor(red: 0.10, green: 0.22, blue: 0.80, alpha: 1).cgColor,
                UIColor(red: 0.42, green: 0.16, blue: 0.86, alpha: 1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            cg.setLineWidth(60)
            for (index, radius) in stride(from: 250.0, through: 1450.0, by: 300.0).enumerated() {
                let alpha = index.isMultiple(of: 2) ? 0.35 : 0.2
                cg.setStrokeColor(UIColor(red: 0.6, green: 0.7, blue: 1, alpha: alpha).cgColor)
                cg.strokeEllipse(in: CGRect(x: size.width * 0.3 - radius, y: size.height * 0.6 - radius, width: radius * 2, height: radius * 2))
            }
        }
        guard let cgImage = drawn.cgImage else { return drawn }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .right)
    }
}
#endif
