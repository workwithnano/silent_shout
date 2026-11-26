import PhotosUI
import SwiftUI
import UIKit

/// The camera entry 1.0.1 appended to the texture carousel (`icon-texture_camera`), finished:
/// a button beside the last texture that offers "Take Photo" (when there is a camera),
/// "Choose Photo" and, once a photo has been used, "Use Last Photo". The photo is drawn
/// upright, downscaled to the screen's longest edge in pixels, stored, and becomes the
/// background (SPEC.md section 9, "Rewrite additions").
///
/// The art is 200x100 with the camera disc in its left half (the right half is a scrap of
/// cardboard: "completely temporary/ugly" in the 2011 commit); only the disc is shown, cut out
/// round and fitted to the last page's margin. While the photo is the background the disc becomes a round
/// thumbnail of the photo with a white ring.
struct CameraEntry: View {
    @Environment(ShoutSettings.self) private var settings

    /// The photo's size limit in pixels.
    let maxPixelLength: CGFloat

    @State private var showsChoices = false
    @State private var showsLibrary = false
    @State private var showsCamera = false
    @State private var libraryItem: PhotosPickerItem?

    /// Spoken as the carousel's value while the photo is the background.
    static let photoValue = "Photo"

    /// The camera disc inside the 200x100 art, in points (measured from the @2x file).
    static let discDiameter: CGFloat = 90
    static let discCenter = CGPoint(x: 60.25, y: 48.5)

    /// The disc's side: its own 90 pt, shrunk to fit the last page's margin beside the
    /// 200 pt texture art with a few points either side (never under a 44 pt target).
    static func side(pageWidth: CGFloat) -> CGFloat {
        let margin = (pageWidth - OptionsLayout.optionArtSize.width) / 2
        return max(min(discDiameter, margin - 8), 44)
    }

    /// Distance from the page's trailing edge, centring the disc in the margin.
    static func trailingInset(pageWidth: CGFloat, side: CGFloat) -> CGFloat {
        let margin = (pageWidth - OptionsLayout.optionArtSize.width) / 2
        return max((margin - side) / 2, 0)
    }

    var body: some View {
        Button {
            showsChoices = true
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Camera")
        .accessibilityValue(settings.usesPhoto ? "Photo in use" : "")
        .accessibilityHint("Takes or chooses a photo for the background.")
        .accessibilityAddTraits(settings.usesPhoto ? .isSelected : [])
        .accessibilityIdentifier(OptionsAccessibilityID.camera)
        .confirmationDialog("Background Photo", isPresented: $showsChoices, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showsCamera = true }
            }
            Button("Choose Photo") { chooseFromLibrary() }
            if settings.hasStoredPhoto, !settings.usesPhoto {
                Button("Use Last Photo") { settings.useLastPhoto() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showsLibrary, selection: $libraryItem, matching: .images, preferredItemEncoding: .current)
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            libraryItem = nil
            Task { @MainActor in
                guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                use(image)
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { image in
                showsCamera = false
                if let image { use(image) }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var label: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            if settings.usesPhoto, let thumbnail = settings.photoThumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            } else {
                // The art scaled so its disc fills `side`, cut out round.
                let factor = side / Self.discDiameter
                Image(ShoutTexture.cameraCarouselImageName)
                    .resizable()
                    .frame(width: OptionsLayout.optionArtSize.width * factor, height: OptionsLayout.optionArtSize.height * factor)
                    .offset(x: side / 2 - Self.discCenter.x * factor, y: side / 2 - Self.discCenter.y * factor)
                    .frame(width: side, height: side, alignment: .topLeading)
                    .clipShape(Circle())
            }
        }
        .contentShape(Circle())
    }

    private func chooseFromLibrary() {
        #if DEBUG
        if UITestHooks.usesPhotoFixture {
            use(PhotoFixture.make())
            return
        }
        #endif
        showsLibrary = true
    }

    private func use(_ image: UIImage) {
        let prepared = PhotoProcessing.prepared(image, maxPixelLength: maxPixelLength)
        try? settings.usePhoto(prepared)
    }
}

/// The system camera (`UIImagePickerController`, `NSCameraUsageDescription`). Reports the
/// photo taken, or nil when cancelled.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        nonisolated func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            MainActor.assumeIsolated { onFinish(image) }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            MainActor.assumeIsolated { onFinish(nil) }
        }
    }
}
