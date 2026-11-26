// Video helpers for `make record-marquee`, using only what macOS ships (AVFoundation,
// CoreGraphics, ImageIO); ffmpeg is not installed on this Mac.
//
//   marquee-video rotate <in.mov> <out.mp4>         upright H.264 copy at half size
//   marquee-video frames <in.mov> <prefix> <s>...   upright full-size PNGs at those seconds
//   marquee-video compare <a.png> <b.png> <out.png> one above the other, a gap between
//   marquee-video match <ref.png> <in.mov> <out.png> <from s> <to s>
//                                                  the frame in that stretch most like ref
//   marquee-video info <file>                      duration, pixel size, codec, bytes
//
// The simulator records the phone's portrait framebuffer. The shout is filmed in device
// landscape left, so its picture is turned a quarter turn clockwise in the file; turning it a
// quarter turn anticlockwise makes it upright (the same as `sips -r 270` on its screenshots).

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("marquee-video: \(message)\n".utf8))
    exit(1)
}

/// Maps a portrait frame of `size` pixels onto its upright landscape picture (y down).
func uprightTransform(for size: CGSize) -> CGAffineTransform {
    // (x, y) -> (y, width - x): a quarter turn anticlockwise on screen.
    CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: size.width)
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fail("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("cannot finish \(url.path)") }
}

func loadImage(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("cannot read \(path)") }
    return image
}

func uprightImage(_ image: CGImage) -> CGImage {
    let width = image.height, height = image.width
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fail("no context") }
    // CoreGraphics is y up: a quarter turn anticlockwise on screen is +90 degrees here.
    context.translateBy(x: CGFloat(width), y: 0)
    context.rotate(by: .pi / 2)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let result = context.makeImage() else { fail("no image") }
    return result
}

func videoTrack(_ asset: AVURLAsset) async throws -> AVAssetTrack {
    guard let track = try await asset.loadTracks(withMediaType: .video).first else { fail("no video track") }
    return track
}

func rotate(_ input: String, _ output: String) async throws {
    let asset = AVURLAsset(url: URL(fileURLWithPath: input))
    let track = try await videoTrack(asset)
    let size = try await track.load(.naturalSize)
    let duration = try await asset.load(.duration)
    let factor: CGFloat = 0.5
    let transform = uprightTransform(for: size).concatenating(CGAffineTransform(scaleX: factor, y: factor))

    var layer = AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)
    layer.setTransform(transform, at: .zero)
    let instruction = AVVideoCompositionInstruction(configuration: .init(
        layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layer)],
        timeRange: CMTimeRange(start: .zero, duration: duration)
    ))
    // Even dimensions for H.264.
    let composition = AVVideoComposition(configuration: .init(
        frameDuration: CMTime(value: 1, timescale: 60),
        instructions: [instruction],
        renderSize: CGSize(
            width: (size.height * factor / 2).rounded() * 2,
            height: (size.width * factor / 2).rounded() * 2
        )
    ))

    // AVAssetExportSession's presets either shrink the picture or use bitrates that make a
    // 17 s clip over 20 MB; a reader and writer let the bitrate be set (about 0.6 MB a second).
    let reader = try AVAssetReader(asset: asset)
    let readerOutput = AVAssetReaderVideoCompositionOutput(
        videoTracks: [track],
        videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    )
    readerOutput.videoComposition = composition
    reader.add(readerOutput)

    let url = URL(fileURLWithPath: output)
    try? FileManager.default.removeItem(at: url)
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: composition.renderSize.width,
        AVVideoHeightKey: composition.renderSize.height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 5_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
    ])
    input.expectsMediaDataInRealTime = false
    writer.add(input)
    guard reader.startReading(), writer.startWriting() else {
        fail("cannot start: \(reader.error?.localizedDescription ?? writer.error?.localizedDescription ?? "?")")
    }
    writer.startSession(atSourceTime: .zero)
    while let sample = readerOutput.copyNextSampleBuffer() {
        while !input.isReadyForMoreMediaData { usleep(2_000) }
        guard input.append(sample) else { fail("append failed: \(writer.error?.localizedDescription ?? "?")") }
    }
    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else { fail("write failed: \(writer.error?.localizedDescription ?? "?")") }
}

func frames(_ input: String, _ prefix: String, _ seconds: [Double]) async throws {
    let asset = AVURLAsset(url: URL(fileURLWithPath: input))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    for (index, second) in seconds.enumerated() {
        let (image, actual) = try await generator.image(at: CMTime(seconds: second, preferredTimescale: 600))
        let url = URL(fileURLWithPath: "\(prefix)-\(index + 1).png")
        writePNG(uprightImage(image), to: url)
        print(String(format: "%@ at %.3f s", url.lastPathComponent, actual.seconds))
    }
}

/// Grey levels of an image scaled to `width` pixels wide, for comparing frames.
func thumbnail(_ image: CGImage, width: Int) -> [UInt8] {
    let height = max(1, image.height * width / image.width)
    var bytes = [UInt8](repeating: 0, count: width * height)
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        context?.interpolationQuality = .medium
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return bytes
}

/// Finds the frame between two times whose upright picture is closest to `reference` (the
/// marquee at the same place), and writes it full size.
func match(_ reference: String, _ input: String, _ output: String, from: Double, to: Double) async throws {
    let target = thumbnail(loadImage(reference), width: 240)
    let asset = AVURLAsset(url: URL(fileURLWithPath: input))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    var best: (score: Int, time: CMTime)?
    var time = from
    while time <= to {
        let (image, actual) = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
        let candidate = thumbnail(uprightImage(image), width: 240)
        let score = zip(candidate, target).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        if best == nil || score < best!.score { best = (score, actual) }
        time += 1.0 / 60
    }
    guard let best else { fail("no frames") }
    let (image, _) = try await generator.image(at: best.time)
    writePNG(uprightImage(image), to: URL(fileURLWithPath: output))
    print(String(format: "%@: frame at %.3f s, mean grey difference %.2f", (output as NSString).lastPathComponent,
                 best.time.seconds, Double(best.score) / Double(target.count)))
}

func compare(_ a: String, _ b: String, _ output: String) {
    let top = loadImage(a), bottom = loadImage(b)
    let gap = 24
    let width = max(top.width, bottom.width)
    let height = top.height + gap + bottom.height
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fail("no context") }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    // y up: the first image goes at the top.
    context.draw(top, in: CGRect(x: 0, y: bottom.height + gap, width: top.width, height: top.height))
    context.draw(bottom, in: CGRect(x: 0, y: 0, width: bottom.width, height: bottom.height))
    guard let image = context.makeImage() else { fail("no image") }
    writePNG(image, to: URL(fileURLWithPath: output))
}

func info(_ path: String) async throws {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let track = try await videoTrack(asset)
    let size = try await track.load(.naturalSize)
    let duration = try await asset.load(.duration)
    let descriptions = try await track.load(.formatDescriptions)
    let codec = descriptions.first.map { description -> String in
        let code = CMFormatDescriptionGetMediaSubType(description).bigEndian
        return withUnsafeBytes(of: code) { String(decoding: $0, as: UTF8.self) }
    } ?? "?"
    let bytes = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
    print(String(format: "%@: %.2f s, %dx%d, %@, %.1f MB", (path as NSString).lastPathComponent,
                 duration.seconds, Int(size.width), Int(size.height), codec, Double(bytes) / 1_000_000))
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { fail("usage: rotate|frames|compare|info ...") }
switch arguments[1] {
case "rotate" where arguments.count == 4:
    try await rotate(arguments[2], arguments[3])
case "frames" where arguments.count >= 5:
    try await frames(arguments[2], arguments[3], arguments[4...].compactMap(Double.init))
case "compare" where arguments.count == 5:
    compare(arguments[2], arguments[3], arguments[4])
case "match" where arguments.count == 7:
    guard let from = Double(arguments[5]), let to = Double(arguments[6]) else { fail("match: times") }
    try await match(arguments[2], arguments[3], arguments[4], from: from, to: to)
case "info":
    try await info(arguments[2])
default:
    fail("usage: rotate|frames|compare|info ...")
}
