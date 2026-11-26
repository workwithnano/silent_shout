import Foundation
import MessageUI
import Photos
import UIKit

/// The "Export Shout" sheet's actions (SPEC.md section 9), in the original's order. Cancel is
/// the sheet's own cancel button.
enum ExportAction: CaseIterable, Sendable {
    case saveToCameraRoll
    case sendInMessages

    var title: String {
        switch self {
        case .saveToCameraRoll: "Save to Camera Roll"
        case .sendInMessages: "Send in iMessage"
        }
    }

    /// The actions to offer: "Send in iMessage" only when this device can send a message with
    /// a picture attached (never in the simulator), rather than a button that does nothing.
    @MainActor
    static func available(messages: any MessageAvailability) -> [ExportAction] {
        allCases.filter { action in
            switch action {
            case .saveToCameraRoll: true
            case .sendInMessages: messages.canSendImage
            }
        }
    }
}

/// Whether the Messages composer can send the shout. A protocol so tests can take both branches.
@MainActor
protocol MessageAvailability {
    var canSendImage: Bool { get }
}

/// The real check: Messages can send text and attachments, and takes a PNG.
struct DeviceMessageAvailability: MessageAvailability {
    var canSendImage: Bool {
        MFMessageComposeViewController.canSendText()
            && MFMessageComposeViewController.canSendAttachments()
            && MFMessageComposeViewController.isSupportedAttachmentUTI(ShoutExport.imageTypeIdentifier)
    }
}

/// How saving to the photo library ended.
enum PhotoSaveResult: Equatable, Sendable {
    case saved
    /// Add-only access was refused (now or earlier) or is restricted.
    case denied
    case failed
}

/// Saves image data to the photo library. A protocol so UI tests can swap in a fake
/// (`-UITestPhotoSaver saved|denied`) instead of the real permission prompt and library.
protocol PhotoLibrarySaving: Sendable {
    func save(_ imageData: Data) async -> PhotoSaveResult
}

/// The real saver: asks for add-only access (`NSPhotoLibraryAddUsageDescription`), which can
/// add pictures but never read the library, then adds the image as a new photo.
struct SystemPhotoLibrarySaver: PhotoLibrarySaving {
    func save(_ imageData: Data) async -> PhotoSaveResult {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .denied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: nil)
            }
            return .saved
        } catch {
            return .failed
        }
    }
}

#if DEBUG
/// UI tests' stand-in for the photo library: answers at once, touches nothing on the device.
struct FakePhotoLibrarySaver: PhotoLibrarySaving {
    static let launchArgument = "-UITestPhotoSaver"

    let result: PhotoSaveResult

    func save(_ imageData: Data) async -> PhotoSaveResult { result }

    /// The fake asked for on the command line (`-UITestPhotoSaver saved` or `denied`), if any.
    static var fromLaunchArguments: FakePhotoLibrarySaver? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: launchArgument), index + 1 < arguments.count else { return nil }
        switch arguments[index + 1] {
        case "saved": return FakePhotoLibrarySaver(result: .saved)
        case "denied": return FakePhotoLibrarySaver(result: .denied)
        case "failed": return FakePhotoLibrarySaver(result: .failed)
        default: return nil
        }
    }
}
#endif

/// What both export actions send: the shout as it is on screen (PLAN ruling 8), drawn by
/// `ShoutRenderer` at the screen's size and scale, so the picture has the screen's pixel size.
@MainActor
enum ShoutExport {
    static let imageTypeIdentifier = "public.png"
    static let attachmentFileName = "Silent Shout.png"

    /// The on-screen shout, background and text, at `size` points and `scale` pixels per point.
    /// In scroll mode the marquee is at its start position.
    static func image(of scene: ShoutScene, size: CGSize, scale: CGFloat) -> UIImage {
        ShoutRenderer.image(of: scene, size: size, scale: scale, marqueeTime: 0, content: .full)
    }

    /// PNG data for the photo library and Messages.
    static func pngData(of scene: ShoutScene, size: CGSize, scale: CGFloat) -> Data? {
        image(of: scene, size: size, scale: scale).pngData()
    }

    /// The saver to use: the UI tests' fake when one is asked for, else the system's.
    static var photoSaver: any PhotoLibrarySaving {
        #if DEBUG
        if let fake = FakePhotoLibrarySaver.fromLaunchArguments { return fake }
        #endif
        return SystemPhotoLibrarySaver()
    }
}
