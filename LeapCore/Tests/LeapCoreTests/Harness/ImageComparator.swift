import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Compares two renders as decoded sRGB RGBA8 buffers – never PNG bytes or
/// `NSImage`s, whose encoders and colour spaces say nothing about pixels.
enum ImageComparator {
    /// Measured steady-state difference is 0 %, so this is drift headroom
    /// rather than a mask.
    static let pixelFraction = 0.001
    static let channelTolerance = 8

    /// `description` is load-bearing: swift-testing expands a failed
    /// `#expect`'s sub-expressions, and the synthesised one for `bytes` ran to
    /// 21 MB of log per failing matrix.
    struct Buffer: Sendable, CustomStringConvertible {
        let bytes: [UInt8]
        let width: Int
        let height: Int

        var pixelCount: Int { width * height }

        var description: String { "\(width)x\(height) sRGB buffer" }
    }

    struct Difference: Sendable {
        let differingPixels: Int
        let pixelCount: Int
        let maxChannelDelta: Int
        let sizeMismatch: Bool

        var fraction: Double {
            pixelCount == 0 ? 1 : Double(differingPixels) / Double(pixelCount)
        }

        var exceedsTolerance: Bool {
            sizeMismatch || fraction > ImageComparator.pixelFraction
        }

        var summary: String {
            guard !sizeMismatch else { return "image sizes differ" }

            return String(format: "%d of %d pixels differ (%.4f %%), max channel delta %d",
                          differingPixels, pixelCount, fraction * 100, maxChannelDelta)
        }
    }

    // MARK: - Decoding

    static func buffer(of image: CGImage) -> Buffer? {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let drawn: Bool = bytes.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        return drawn ? Buffer(bytes: bytes, width: width, height: height) : nil
    }

    // MARK: - Comparison

    /// Buffer equality first: the pass case never pays for the pixel walk.
    static func compare(_ expected: Buffer, _ actual: Buffer) -> Difference {
        guard expected.width == actual.width, expected.height == actual.height else {
            return Difference(differingPixels: max(expected.pixelCount, actual.pixelCount),
                              pixelCount: max(expected.pixelCount, actual.pixelCount),
                              maxChannelDelta: 255,
                              sizeMismatch: true)
        }

        if expected.bytes == actual.bytes {
            return Difference(differingPixels: 0, pixelCount: expected.pixelCount,
                              maxChannelDelta: 0, sizeMismatch: false)
        }

        var differing = 0
        var maxDelta = 0

        expected.bytes.withUnsafeBufferPointer { left in
            actual.bytes.withUnsafeBufferPointer { right in
                var offset = 0
                while offset + 3 < left.count {
                    var worst = 0
                    for channel in 0..<4 {
                        let delta = abs(Int(left[offset + channel])
                                        - Int(right[offset + channel]))
                        if delta > worst { worst = delta }
                    }
                    if worst > channelTolerance { differing += 1 }
                    if worst > maxDelta { maxDelta = worst }
                    offset += 4
                }
            }
        }

        return Difference(differingPixels: differing, pixelCount: expected.pixelCount,
                          maxChannelDelta: maxDelta, sizeMismatch: false)
    }

    /// Where two same-sized renders differ beyond `channelTolerance`, in pixels.
    struct Change: Sendable, CustomStringConvertible {
        let rows: IndexSet
        let columns: ClosedRange<Int>

        var description: String {
            "rows \(rows.first ?? 0)…\(rows.last ?? 0), columns \(columns)"
        }
    }

    /// `nil` when the renders match. Sizes must agree – a config change never
    /// resizes the tile.
    /// `columns` narrows the comparison, e.g. to one month of the two-month tile.
    static func change(from before: Buffer, to after: Buffer,
                       columns: Range<Int>? = nil) -> Change? {
        precondition(before.width == after.width && before.height == after.height,
                     "renders of different sizes")

        let columns = columns ?? 0..<before.width
        var rows = IndexSet()
        var minX = Int.max
        var maxX = Int.min

        before.bytes.withUnsafeBufferPointer { left in
            after.bytes.withUnsafeBufferPointer { right in
                for y in 0..<before.height {
                    for x in columns {
                        let offset = (y * before.width + x) * 4
                        for channel in 0..<4
                        where abs(Int(left[offset + channel]) - Int(right[offset + channel]))
                            > channelTolerance {
                            rows.insert(y)
                            minX = min(minX, x)
                            maxX = max(maxX, x)
                            break
                        }
                    }
                }
            }
        }

        return rows.isEmpty ? nil : Change(rows: rows, columns: minX...maxX)
    }

    // Raw pointers throughout: these run on every case in the matrix in an
    // unoptimised test build, and `Array` subscripts cost seconds across it.

    static func isFullyOpaque(_ buffer: Buffer) -> Bool {
        buffer.bytes.withUnsafeBufferPointer { bytes in
            var index = 3
            while index < bytes.count {
                if bytes[index] != 255 { return false }
                index += 4
            }
            return true
        }
    }

    static func opaquePixelCount(_ buffer: Buffer) -> Int {
        buffer.bytes.withUnsafeBufferPointer { bytes in
            var index = 3
            var count = 0
            while index < bytes.count {
                if bytes[index] == 255 { count += 1 }
                index += 4
            }
            return count
        }
    }

    /// A flat render – the blank-render failure class – has one RGB value.
    static func isFlat(_ buffer: Buffer) -> Bool {
        guard buffer.pixelCount > 0 else { return true }

        return buffer.bytes.withUnsafeBufferPointer { bytes in
            let red = bytes[0], green = bytes[1], blue = bytes[2]
            var offset = 4
            while offset + 2 < bytes.count {
                if bytes[offset] != red || bytes[offset + 1] != green
                    || bytes[offset + 2] != blue {
                    return false
                }
                offset += 4
            }
            return true
        }
    }

    // MARK: - Diff image

    /// Any channel delta lights the pixel red, so a one-pixel baseline shift
    /// is visible at a glance.
    static func amplifiedDiff(expected: Buffer, actual: Buffer) -> CGImage? {
        guard expected.width == actual.width, expected.height == actual.height,
              let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }

        // The context owns its bitmap (`data: nil`). Backing it with a Swift
        // `Array` would hand `CGContext` memory that dies at the end of the
        // closure – on the one path that must work when all else has failed.
        guard let context = CGContext(data: nil,
                                      width: expected.width,
                                      height: expected.height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: expected.width * 4,
                                      space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let base = context.data
        else { return nil }

        let bytes = base.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * expected.height)
        let stride = context.bytesPerRow

        expected.bytes.withUnsafeBufferPointer { left in
            actual.bytes.withUnsafeBufferPointer { right in
                for y in 0..<expected.height {
                    for x in 0..<expected.width {
                        let source = (y * expected.width + x) * 4
                        var worst = 0
                        for channel in 0..<4 {
                            worst = max(worst, abs(Int(left[source + channel])
                                                   - Int(right[source + channel])))
                        }
                        let destination = y * stride + x * 4
                        bytes[destination] = worst > 0 ? 255 : 0
                        bytes[destination + 1] = 0
                        bytes[destination + 2] = 0
                        bytes[destination + 3] = 255
                    }
                }
            }
        }

        return context.makeImage()
    }

    // MARK: - PNG

    static func pngData(of image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return data as Data
    }

    static func image(fromPNG data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
