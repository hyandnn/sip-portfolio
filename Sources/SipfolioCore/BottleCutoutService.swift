import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

public struct CutoutCandidate: Identifiable, Sendable {
    public let id: Int
    public let png: Data
    public init(id: Int, png: Data) { self.id = id; self.png = png }
}

public actor BottleCutoutService {
    private let context = CIContext(options: [.cacheIntermediates: false])
    public init() {}

    public func loadPhoto(at url: URL) throws -> Data {
        let scope = url.startAccessingSecurityScopedResource()
        defer { if scope { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 50 * 1024 * 1024 else { throw SipfolioError.imageTooLarge }
        let data = try Data(contentsOf: url)
        return try normalizedPNG(from: data, maxPixelSize: 2400)
    }

    public func normalizedPNG(from data: Data, maxPixelSize: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw SipfolioError.invalidImage }
        return try pngData(for: image)
    }

    public func cutout(from data: Data) throws -> [CutoutCandidate] {
        guard let image = CIImage(data: data) else { throw SipfolioError.invalidImage }
        let handler = VNImageRequestHandler(ciImage: image)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw SipfolioError.noSubject
        }
        var candidates: [CutoutCandidate] = []
        for instance in observation.allInstances.prefix(8) {
            let buffer = try observation.generateMaskedImage(ofInstances: IndexSet(integer: instance), from: handler, croppedToInstancesExtent: true)
            let cutout = CIImage(cvPixelBuffer: buffer)
            // Add a small white contour while keeping the surrounding pixels transparent.
            let outline = max(3, min(24, max(cutout.extent.width, cutout.extent.height) * 0.01))
            let padding = outline + 4
            let extent = cutout.extent.insetBy(dx: -padding, dy: -padding)
            let alpha = cutout.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
            ]).applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": outline])
            let sticker = cutout.composited(over: alpha).cropped(to: extent)
            guard let cgImage = context.createCGImage(sticker, from: extent) else { throw SipfolioError.invalidImage }
            candidates.append(CutoutCandidate(id: instance, png: try pngData(for: cgImage)))
        }
        return candidates
    }

    public func jpegForRecognition(from data: Data) throws -> Data {
        let normalized = try normalizedPNG(from: data, maxPixelSize: 1280)
        guard let image = CIImage(data: normalized),
              let cgImage = context.createCGImage(image.composited(over: CIImage(color: .white).cropped(to: image.extent)), from: image.extent) else { throw SipfolioError.invalidImage }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw SipfolioError.invalidImage }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw SipfolioError.invalidImage }
        return output as Data
    }

    private func pngData(for image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw SipfolioError.invalidImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw SipfolioError.invalidImage }
        return data as Data
    }

    public func largestSubject(from candidates: [CutoutCandidate]) -> CutoutCandidate? {
        func area(_ candidate: CutoutCandidate) -> Int {
            guard let source = CGImageSourceCreateWithData(candidate.png as CFData, nil),
                  let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = info[kCGImagePropertyPixelWidth] as? Int,
                  let height = info[kCGImagePropertyPixelHeight] as? Int else { return 0 }
            return width * height
        }
        return candidates.max { area($0) < area($1) }
    }
}
