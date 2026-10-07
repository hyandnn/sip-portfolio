import Testing
import Foundation
import ImageIO
@testable import SipfolioCore

@Test
func realBottleBecomesTransparentSticker() async throws {
    let url = try #require(Bundle.module.url(forResource: "hendricks", withExtension: "jpg", subdirectory: "Fixtures"))
    let service = BottleCutoutService()
    let photo = try await service.loadPhoto(at: url)
    let candidates = try await service.cutout(from: photo)
    #expect(!candidates.isEmpty)
    let sticker = try #require(candidates.first?.png)
    let source = try #require(CGImageSourceCreateWithData(sticker as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width > 50 && image.height > 100)
    #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipLast && image.alphaInfo != .noneSkipFirst)
    let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let pixels = try #require(context.data?.assumingMemoryBound(to: UInt8.self))
    var transparent = 0
    var opaque = 0
    for index in 0..<(image.width * image.height) {
        if pixels[index * 4 + 3] == 0 { transparent += 1 }
        if pixels[index * 4 + 3] > 250 { opaque += 1 }
    }
    // Reject a fully opaque rectangle or an accidentally empty mask.
    #expect(transparent > image.width * image.height / 20)
    #expect(opaque > image.width * image.height / 20)
    if let path = ProcessInfo.processInfo.environment["SIPFOLIO_QA_OUTPUT"] {
        let output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try photo.write(to: output.appendingPathComponent("bottle-original.png"))
        try sticker.write(to: output.appendingPathComponent("bottle-sticker.png"))
    }
}
