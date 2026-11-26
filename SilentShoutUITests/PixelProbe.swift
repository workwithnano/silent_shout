import XCTest

/// Reads colours off a screenshot, so a test can tell the camera fixture (blue everywhere) from
/// the paper textures (cream, white, brown) without any test-only hooks in the app.
@MainActor
struct PixelProbe {
    let image: UIImage
    /// Screenshot pixels per screen point, in the screenshot's own (device portrait) frame.
    let pixelsPerPoint: CGFloat

    init(screenshot: XCUIScreenshot = XCUIScreen.main.screenshot(), app: XCUIApplication) {
        image = screenshot.image
        let width = CGFloat(image.cgImage?.width ?? 0)
        // The window's short side is the device's portrait width, whichever way it is turned.
        let frame = app.windows.firstMatch.frame
        pixelsPerPoint = width / max(min(frame.width, frame.height), 1)
    }

    /// The colour at a point of the screenshot, 0...255, in device-portrait points.
    func color(atPoint point: CGPoint) -> (r: Int, g: Int, b: Int) {
        color(atPixelX: Int(point.x * pixelsPerPoint), y: Int(point.y * pixelsPerPoint))
    }

    /// The colour at a normalised position of the screenshot (0...1 each way, device portrait).
    func color(atNormalized x: CGFloat, _ y: CGFloat) -> (r: Int, g: Int, b: Int) {
        guard let cgImage = image.cgImage else { return (0, 0, 0) }
        return color(atPixelX: Int(x * CGFloat(cgImage.width - 1)), y: Int(y * CGFloat(cgImage.height - 1)))
    }

    private func color(atPixelX x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
        guard let cgImage = image.cgImage else { return (0, 0, 0) }
        var data = [UInt8](repeating: 0, count: 4)
        data.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(cgImage, in: CGRect(x: -x, y: -(cgImage.height - 1 - y), width: cgImage.width, height: cgImage.height))
        }
        return (Int(data[0]), Int(data[1]), Int(data[2]))
    }

    /// The fixture photo's colours: clearly more blue than red. No paper texture is.
    static func isFixtureBlue(_ color: (r: Int, g: Int, b: Int)) -> Bool {
        color.b > 120 && color.b - color.r > 50
    }

    /// The shout's background at both short edges of the landscape screen (outside the
    /// 480x320 canvas, so never under fit-mode text). True when both are the fixture's blue.
    func shoutEdgesAreFixture() -> Bool {
        [color(atNormalized: 0.5, 0.03), color(atNormalized: 0.5, 0.97)].allSatisfy(Self.isFixtureBlue)
    }

    func shoutEdgesAreNotFixture() -> Bool {
        ![color(atNormalized: 0.5, 0.03), color(atNormalized: 0.5, 0.97)].contains(where: Self.isFixtureBlue)
    }
}
