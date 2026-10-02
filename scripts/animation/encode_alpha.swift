// Encode Blender RGBA frames into a local HEVC movie retaining transparency.
// Usage: swift encode_alpha.swift FRAMES_DIRECTORY OUTPUT.mov FPS
import AVFoundation
import CoreGraphics
import ImageIO
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1)
}
let args = CommandLine.arguments
 guard args.count == 4, let fps = Int32(args[3]), fps > 0 else { fail("frames, output.mov, fps required") }
let folder = URL(fileURLWithPath: args[1], isDirectory: true)
let frames = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasPrefix("frame_") && $0.pathExtension == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard let first = frames.first,
      let source = CGImageSourceCreateWithURL(first as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("No readable frames") }
let output = URL(fileURLWithPath: args[2])
if FileManager.default.fileExists(atPath: output.path) { try FileManager.default.removeItem(at: output) }
let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
                             AVVideoWidthKey: image.width, AVVideoHeightKey: image.height,
                             AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000,
                                                               AVVideoAllowFrameReorderingKey: false]]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: image.width,
    kCVPixelBufferHeightKey as String: image.height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
guard writer.canAdd(input) else { fail("HEVC-alpha input unavailable") }
writer.add(input)
guard writer.startWriting() else { fail("\(writer.error!)") }
writer.startSession(atSourceTime: .zero)
for (index, url) in frames.enumerated() {
    while !input.isReadyForMoreMediaData {
        if writer.status == .failed { fail("\(writer.error!)") }
        Thread.sleep(forTimeInterval: 0.002)
    }
    autoreleasepool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let frame = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let pool = adaptor.pixelBufferPool else { fail("Unreadable frame or missing pool") }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
              let buffer else { fail("Pixel allocation failed") }
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { fail("No RGBA context") }
        context.clear(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(frame, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: fps)) else { fail("Append failed: \(String(describing: writer.error))") }
    }
}
input.markAsFinished()
let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
finished.wait()
guard writer.status == .completed else { fail("Encoding failed: \(String(describing: writer.error))") }
print("Encoded \(frames.count) frames with alpha: \(output.path)")
