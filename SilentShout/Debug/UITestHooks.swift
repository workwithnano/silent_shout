#if DEBUG
import SwiftUI
import UIKit

/// The launch arguments the UI tests pass, and what they switch on. All of it is compiled into
/// debug builds only, and each hook does nothing unless its argument is on the command line, so
/// a normal launch (or any release build) behaves as if this file did not exist.
///
/// The UI tests repeat these strings, since a UI test bundle cannot import the app.
enum UITestHooks {
    /// Clear the stored settings and photo before the model is created, so a test starts from
    /// the original defaults.
    static let resetSettings = "-UITestResetSettings"
    /// `-UITestPhotoSaver saved|denied|failed`: save to a fake photo library that answers at
    /// once, instead of the real permission prompt and the shared simulator's library.
    static let photoSaver = "-UITestPhotoSaver"
    /// "Choose Photo" uses `PhotoFixture` instead of opening the system photo picker.
    static let photoFixture = "-UITestPhotoFixture"
    /// The shout carries `ShoutStateProbe`, so a test can wait until the app has seen an
    /// orientation change before checking what it did about it.
    static let shoutState = "-UITestShoutState"

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var resetsSettings: Bool { arguments.contains(resetSettings) }
    static var usesPhotoFixture: Bool { arguments.contains(photoFixture) }
    static var showsShoutState: Bool { arguments.contains(shoutState) }

    /// The fake photo library asked for, if any.
    static var fakePhotoSaver: FakePhotoLibrarySaver? {
        guard let index = arguments.firstIndex(of: photoSaver), index + 1 < arguments.count else { return nil }
        switch arguments[index + 1] {
        case "saved": return FakePhotoLibrarySaver(result: .saved)
        case "denied": return FakePhotoLibrarySaver(result: .denied)
        case "failed": return FakePhotoLibrarySaver(result: .failed)
        default: return nil
        }
    }
}

/// The UI tests' stand-in for the photo library: answers at once, touches nothing on the device.
struct FakePhotoLibrarySaver: PhotoLibrarySaving {
    let result: PhotoSaveResult

    func save(_ imageData: Data) async -> PhotoSaveResult { result }
}

/// A photo the app draws for UI tests, so they never drive the system picker: a blue-to-violet
/// gradient with lighter rings, 2000x3000 pixels stored with orientation `.right`, so it shows
/// as a 3000x2000 landscape picture and exercises the orientation fix like a real camera photo.
/// Every pixel is clearly blue, which the UI tests sample to tell it from the paper textures.
enum PhotoFixture {
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

/// An invisible element on the shout whose value is the device orientation the app last
/// received and whether the shout is still up, for example "portrait shouting" or
/// "portrait leaving". Nothing changes on screen when the phone turns upright under the export
/// sheet (the interface stays landscape), so this is how a test knows the turn has been
/// handled before it checks that the shout stayed.
///
/// A second element, `debug.shoutPresented`, reads "presented" once the shout's presentation
/// animation has finished ("presenting" before): touches are ignored until then, so tests wait
/// for it before tapping the shout.
struct ShoutStateProbe: View {
    static let identifier = "debug.shoutState"

    static let presentedIdentifier = "debug.shoutPresented"

    let orientation: UIDeviceOrientation
    let isShouting: Bool
    let isPresented: Bool

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("Shout state")
                .accessibilityIdentifier(Self.identifier)
                .accessibilityValue("\(Self.name(of: orientation)) \(isShouting ? "shouting" : "leaving")")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("Shout presentation")
                .accessibilityIdentifier(Self.presentedIdentifier)
                .accessibilityValue(isPresented ? "presented" : "presenting")
        }
        .allowsHitTesting(false)
    }

    static func name(of orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: "portrait"
        case .portraitUpsideDown: "upsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        case .faceUp: "faceUp"
        case .faceDown: "faceDown"
        default: "unknown"
        }
    }
}
#endif
