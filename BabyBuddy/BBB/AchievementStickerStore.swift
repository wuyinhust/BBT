import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct CustomAchievement: Identifiable, Codable, Hashable {
    let id: UUID
    var templateID: String?
    var name: String
    var description: String
    var note: String
    var completedAt: Date
    var stickerFilename: String
    var originalFilename: String?

    init(
        id: UUID = UUID(),
        templateID: String? = nil,
        name: String,
        description: String,
        note: String,
        completedAt: Date = Date(),
        stickerFilename: String,
        originalFilename: String? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.name = name
        self.description = description
        self.note = note
        self.completedAt = completedAt
        self.stickerFilename = stickerFilename
        self.originalFilename = originalFilename
    }
}

struct AchievementTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let symbol: String
}

@MainActor
final class AchievementStickerStore: ObservableObject {
    @Published private(set) var achievements: [CustomAchievement] = []

    private let metadataFilename = "custom_achievements.json"
    private let stickerImageCache = NSCache<NSString, UIImage>()
    private let thumbnailImageCache = NSCache<NSString, UIImage>()

    init() {
        load()
    }

    func add(templateID: String? = nil, name: String, description: String, note: String, sourceImage: UIImage, stickerImage: UIImage? = nil) throws -> CustomAchievement {
        let id = UUID()
        let originalFilename = "\(id.uuidString)-original.jpg"
        let stickerFilename = "\(id.uuidString)-sticker.png"
        let finalStickerImage = stickerImage ?? StickerGenerator.generateSticker(from: sourceImage)
        let originalURL = imageURL(for: originalFilename)
        let stickerURL = imageURL(for: stickerFilename)

        do {
            try saveJPEG(sourceImage.optimizedForStickerInput(), filename: originalFilename)
            try savePNG(finalStickerImage, filename: stickerFilename)

            let achievement = CustomAchievement(
                id: id,
                templateID: templateID,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "自定义成就" : name,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "记录宝宝的一个特别时刻" : description,
                note: note,
                stickerFilename: stickerFilename,
                originalFilename: originalFilename
            )
            let updatedAchievements = [achievement] + achievements
            try persist(updatedAchievements)

            achievements = updatedAchievements
            cache(finalStickerImage, for: stickerFilename)
            return achievement
        } catch {
            try? FileManager.default.removeItem(at: originalURL)
            try? FileManager.default.removeItem(at: stickerURL)
            throw error
        }
    }

    func achievement(for templateID: String) -> CustomAchievement? {
        achievements.first { $0.templateID == templateID }
    }

    func updateNote(for achievement: CustomAchievement, note: String) {
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }) else { return }
        let previousNote = achievements[index].note
        achievements[index].note = note
        do {
            try persist(achievements)
        } catch {
            achievements[index].note = previousNote
        }
    }

    func imageURL(for filename: String) -> URL {
        imagesDirectory.appendingPathComponent(filename)
    }

    func stickerImage(for achievement: CustomAchievement) -> UIImage? {
        stickerImage(named: achievement.stickerFilename)
    }

    func thumbnailImage(for achievement: CustomAchievement, maxSide: CGFloat = 240) -> UIImage? {
        let cacheKey = "\(achievement.stickerFilename)-thumb-\(Int(maxSide))" as NSString
        if let image = thumbnailImageCache.object(forKey: cacheKey) {
            return image
        }
        guard let sticker = stickerImage(for: achievement) else { return nil }
        let thumbnail = sticker.scaledToFit(maxSide: maxSide)
        thumbnailImageCache.setObject(thumbnail, forKey: cacheKey)
        return thumbnail
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([CustomAchievement].self, from: data) else {
            achievements = []
            return
        }
        achievements = decoded.sorted { $0.completedAt > $1.completedAt }
    }

    private func persist(_ achievements: [CustomAchievement]) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(achievements)
        try data.write(to: metadataURL, options: [.atomic])
    }

    private var metadataURL: URL {
        documentsDirectory.appendingPathComponent(metadataFilename)
    }

    private var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent("AchievementStickers", isDirectory: true)
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func savePNG(_ image: UIImage, filename: String) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        guard let data = image.pngData() else { throw AchievementStickerError.imageEncodingFailed }
        try data.write(to: imageURL(for: filename), options: [.atomic])
    }

    private func saveJPEG(_ image: UIImage, filename: String) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        guard let data = image.jpegData(compressionQuality: 0.88) else { throw AchievementStickerError.imageEncodingFailed }
        try data.write(to: imageURL(for: filename), options: [.atomic])
    }

    private func stickerImage(named filename: String) -> UIImage? {
        let cacheKey = filename as NSString
        if let image = stickerImageCache.object(forKey: cacheKey) {
            return image
        }
        guard let image = UIImage(contentsOfFile: imageURL(for: filename).path) else {
            return nil
        }
        cache(image, for: filename)
        return image
    }

    private func cache(_ image: UIImage, for filename: String) {
        stickerImageCache.setObject(image, forKey: filename as NSString)
    }
}

enum AchievementStickerError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "图片保存失败"
        }
    }
}

enum StickerGenerator {
    private struct InstanceStats {
        var area: Int = 0
        var sumX: Double = 0
        var sumY: Double = 0
    }

    static func generateSticker(from image: UIImage) -> UIImage {
        guard let inputCGImage = image.normalized().cgImage else { return image }

        guard let maskedImage = generateForegroundSticker(from: inputCGImage) else {
            return image.normalized().addStickerShadow(shadowRadius: image.normalized().recommendedStickerShadowRadius)
        }
        let trimmedImage = maskedImage.trimTransparentPixels()
        return trimmedImage.addStickerShadow(shadowRadius: trimmedImage.recommendedStickerShadowRadius)
    }

    private static func generateForegroundSticker(from cgImage: CGImage) -> UIImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            let dominantInstances = dominantInstances(in: observation)
            let mask = try observation.generateScaledMaskForImage(forInstances: dominantInstances, from: handler)
            return apply(mask: mask, to: cgImage)
        } catch {
            return nil
        }
    }

    private static func dominantInstances(in observation: VNInstanceMaskObservation) -> IndexSet {
        let allInstances = observation.allInstances
        guard allInstances.count > 1 else { return allInstances }

        let pixelBuffer = observation.instanceMask
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return IndexSet(integer: allInstances.first ?? 1)
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
        var statsByInstance: [Int: InstanceStats] = [:]

        for y in 0..<height {
            let row = pixels.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                let label = Int(row[x])
                guard allInstances.contains(label) else { continue }
                statsByInstance[label, default: InstanceStats()].area += 1
                statsByInstance[label, default: InstanceStats()].sumX += Double(x)
                statsByInstance[label, default: InstanceStats()].sumY += Double(y)
            }
        }

        let centerX = Double(width) / 2
        let centerY = Double(height) / 2
        let maxDistance = hypot(centerX, centerY)

        let bestInstance = statsByInstance.max { lhs, rhs in
            score(for: lhs.value, centerX: centerX, centerY: centerY, maxDistance: maxDistance)
            < score(for: rhs.value, centerX: centerX, centerY: centerY, maxDistance: maxDistance)
        }?.key

        return IndexSet(integer: bestInstance ?? allInstances.first ?? 1)
    }

    private static func score(
        for stats: InstanceStats,
        centerX: Double,
        centerY: Double,
        maxDistance: Double
    ) -> Double {
        guard stats.area > 0 else { return 0 }
        let centroidX = stats.sumX / Double(stats.area)
        let centroidY = stats.sumY / Double(stats.area)
        let distance = hypot(centroidX - centerX, centroidY - centerY)
        let centerWeight = 1 - min(distance / maxDistance, 1)
        return Double(stats.area) + centerWeight * 0.35 * Double(stats.area)
    }

    private static func apply(mask: CVPixelBuffer, to cgImage: CGImage) -> UIImage? {
        let context = CIContext()
        let inputImage = CIImage(cgImage: cgImage)
        let maskImage = CIImage(cvPixelBuffer: mask)
            .transformed(by: CGAffineTransform(
                scaleX: inputImage.extent.width / CGFloat(CVPixelBufferGetWidth(mask)),
                y: inputImage.extent.height / CGFloat(CVPixelBufferGetHeight(mask))
            ))

        let filter = CIFilter.blendWithMask()
        filter.inputImage = inputImage
        filter.backgroundImage = CIImage(color: .clear).cropped(to: inputImage.extent)
        filter.maskImage = maskImage

        guard let outputImage = filter.outputImage,
              let outputCGImage = context.createCGImage(outputImage, from: inputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: outputCGImage, scale: UIScreen.main.scale, orientation: .up)
    }
}

extension UIImage {
    var recommendedStickerShadowRadius: CGFloat {
        min(max(max(size.width, size.height) * 0.014, 6), 14)
    }

    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func optimizedForStickerInput(maxSide: CGFloat = 1200) -> UIImage {
        let normalizedImage = normalized()
        let longestSide = max(normalizedImage.size.width, normalizedImage.size.height)
        guard longestSide > maxSide else { return normalizedImage }

        let scale = maxSide / longestSide
        let targetSize = CGSize(
            width: normalizedImage.size.width * scale,
            height: normalizedImage.size.height * scale
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            normalizedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func addStickerShadow(
        shadowRadius: CGFloat = 10,
        shadowOpacity: CGFloat = 0.18,
        shadowYOffset: CGFloat = 4
    ) -> UIImage {
        let normalizedImage = normalized()
        let padding = shadowRadius * 2.6
        let canvasSize = CGSize(width: normalizedImage.size.width + padding * 2, height: normalizedImage.size.height + padding * 2)
        let imageRect = CGRect(origin: CGPoint(x: padding, y: padding), size: normalizedImage.size)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { context in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))

            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: shadowYOffset),
                blur: shadowRadius,
                color: UIColor.black.withAlphaComponent(shadowOpacity).cgColor
            )
            normalizedImage.draw(in: imageRect)
        }
    }

    func scaledToFit(maxSide: CGFloat) -> UIImage {
        let normalizedImage = normalized()
        let longestSide = max(normalizedImage.size.width, normalizedImage.size.height)
        guard longestSide > maxSide else { return normalizedImage }

        let scale = maxSide / longestSide
        let targetSize = CGSize(
            width: normalizedImage.size.width * scale,
            height: normalizedImage.size.height * scale
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            normalizedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func trimTransparentPixels(alphaThreshold: UInt8 = 8) -> UIImage {
        let normalizedImage = normalized()
        guard let cgImage = normalizedImage.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return normalizedImage
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 4)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foundOpaquePixel = false

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = bytes[offset + min(bytesPerPixel - 1, 3)]
                guard alpha > alphaThreshold else { continue }
                foundOpaquePixel = true
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard foundOpaquePixel else { return normalizedImage }
        let inset: CGFloat = 2
        let originX = max(CGFloat(minX) - inset, 0)
        let originY = max(CGFloat(minY) - inset, 0)
        let cropRect = CGRect(
            x: originX,
            y: originY,
            width: min(CGFloat(maxX - minX + 1) + inset * 2, CGFloat(width) - originX),
            height: min(CGFloat(maxY - minY + 1) + inset * 2, CGFloat(height) - originY)
        )
        guard let cropped = cgImage.cropping(to: cropRect.integral) else {
            return normalizedImage
        }
        return UIImage(cgImage: cropped, scale: normalizedImage.scale, orientation: .up)
    }

}
