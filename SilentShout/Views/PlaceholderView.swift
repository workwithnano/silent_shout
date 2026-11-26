import SwiftUI
import UIKit

/// Phase 1 only: shows every texture and a line in every font with its ink colour, to prove
/// the asset catalog and the bundled fonts load. Phase 2 replaces it with the Options screen.
struct PlaceholderView: View {
    @Environment(ShoutSettings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Silent Shout")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("placeholder.title")

                section("Fonts") {
                    ForEach(ShoutFont.allCases, id: \.self) { font in
                        fontRow(font)
                    }
                }

                section("Textures") {
                    ForEach(ShoutTexture.allCases, id: \.self) { texture in
                        textureRow(texture)
                    }
                }

                section("Saved settings") {
                    Text("font \(settings.font.rawValue), texture \(settings.texture.rawValue), lettering \(settings.sizing.rawValue)")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.white)
                }
            }
            .padding(16)
        }
        .background {
            Image(ChromeImage.mainBackground.rawValue)
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            content()
        }
    }

    private func fontRow(_ font: ShoutFont) -> some View {
        let loaded = font.uiFont(size: 36) != nil
        return VStack(alignment: .leading, spacing: 4) {
            Text("Shout it silently")
                .font(font.font(size: 36))
                .foregroundStyle(font.ink.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Image(ShoutTexture.notecard.previewImageName).resizable().scaledToFill())
                .clipped()
            Text(verbatim: "\(font) · \(font.fontName) · \(loaded ? "loaded" : "MISSING")")
                .font(.caption.monospaced())
                .foregroundStyle(loaded ? .white : .red)
                .accessibilityIdentifier("placeholder.font.\(font.rawValue)")
        }
    }

    private func textureRow(_ texture: ShoutTexture) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(texture.shoutImageName)
                    .resizable()
                    .aspectRatio(480.0 / 320.0, contentMode: .fit)
                Image(texture.previewImageName)
                    .resizable()
                    .aspectRatio(320.0 / 226.0, contentMode: .fit)
            }
            Text(verbatim: "\(texture) · \(texture.shoutImageName)")
                .font(.caption.monospaced())
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    PlaceholderView()
        .environment(ShoutSettings(defaults: UserDefaults(suiteName: "preview")!))
}
