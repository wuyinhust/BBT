import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation
import Foundation
import Photos
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct AchievementAssetFiles {
    var stickerFilename: String
    var originalFilename: String?
    var stickerURL: URL?
    var originalURL: URL?
}

struct AchievementAssetExport {
    var achievementID: UUID
    var stickerFilename: String
    var originalFilename: String?
    var stickerURL: URL?
    var originalURL: URL?
}

struct CustomAchievement: Identifiable, Codable, Hashable {
    let id: UUID
    var templateID: String?
    var name: String
    var description: String
    var note: String
    var completedAt: Date
    var stickerFilename: String
    var originalFilename: String?
    var milestoneID: String?
    var milestoneKind: AchievementMilestoneKind?
    var achievedDayOffset: Int?
    var sourceAssetLocalIdentifier: String?
    var sourceAssetMediaSubtypeRawValue: UInt?
    var livePhotoMovieFilename: String?
    var creationSource: AchievementCreationSource?
    var matchConfidence: Double?

    init(
        id: UUID = UUID(),
        templateID: String? = nil,
        name: String,
        description: String,
        note: String,
        completedAt: Date = Date(),
        stickerFilename: String,
        originalFilename: String? = nil,
        milestoneID: String? = nil,
        milestoneKind: AchievementMilestoneKind? = nil,
        achievedDayOffset: Int? = nil,
        sourceAssetLocalIdentifier: String? = nil,
        sourceAssetMediaSubtypeRawValue: UInt? = nil,
        livePhotoMovieFilename: String? = nil,
        creationSource: AchievementCreationSource? = nil,
        matchConfidence: Double? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.name = name
        self.description = description
        self.note = note
        self.completedAt = completedAt
        self.stickerFilename = stickerFilename
        self.originalFilename = originalFilename
        self.milestoneID = milestoneID
        self.milestoneKind = milestoneKind
        self.achievedDayOffset = achievedDayOffset
        self.sourceAssetLocalIdentifier = sourceAssetLocalIdentifier
        self.sourceAssetMediaSubtypeRawValue = sourceAssetMediaSubtypeRawValue
        self.livePhotoMovieFilename = livePhotoMovieFilename
        self.creationSource = creationSource
        self.matchConfidence = matchConfidence
    }

    var hasLivePhotoSource: Bool {
        if livePhotoMovieFilename != nil { return true }
        guard let sourceAssetMediaSubtypeRawValue else { return false }
        return (sourceAssetMediaSubtypeRawValue & PHAssetMediaSubtype.photoLive.rawValue) != 0
    }
}

struct AchievementTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let symbol: String
    var milestoneKind: AchievementMilestoneKind? = nil
    var targetDayOffset: Int? = nil
    var agePageIndex: Int? = nil
}

enum AchievementMilestoneKind: String, Codable, Hashable {
    case importantDay
    case monthly
    case custom
}

enum AchievementCreationSource: String, Codable, Hashable {
    case manual
    case autoMatched
}

struct AchievementScanPageState: Codable, Hashable {
    var pageIndex: Int
    var scannedAt: Date
    var resultCount: Int
}

struct AchievementAutoMatchScoreBreakdown: Codable, Hashable {
    var favorite: Double
    var facePresence: Double
    var faceArea: Double
    var faceCenter: Double
    var aspect: Double
    var resolution: Double
    var total: Double

    var debugSummary: String {
        [
            "face \(Int((facePresence + faceArea + faceCenter) * 100))",
            "fav \(Int(favorite * 100))",
            "shape \(Int((aspect + resolution) * 100))"
        ].joined(separator: " · ")
    }
}

struct AchievementAutoMatchCandidateRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var pageIndex: Int
    var dayOffset: Int
    var date: Date
    var milestoneID: String?
    var assetLocalIdentifier: String
    var assetMediaSubtypeRawValue: UInt
    var confidence: Double
    var scoreBreakdown: AchievementAutoMatchScoreBreakdown

    init(
        id: UUID = UUID(),
        pageIndex: Int,
        dayOffset: Int,
        date: Date,
        milestoneID: String?,
        assetLocalIdentifier: String,
        assetMediaSubtypeRawValue: UInt,
        confidence: Double,
        scoreBreakdown: AchievementAutoMatchScoreBreakdown
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.dayOffset = dayOffset
        self.date = date
        self.milestoneID = milestoneID
        self.assetLocalIdentifier = assetLocalIdentifier
        self.assetMediaSubtypeRawValue = assetMediaSubtypeRawValue
        self.confidence = confidence
        self.scoreBreakdown = scoreBreakdown
    }
}

@MainActor
final class AchievementStickerStore: ObservableObject {
    @Published private(set) var achievements: [CustomAchievement] = []
    @Published private(set) var scannedPageStates: [Int: AchievementScanPageState] = [:]
    @Published private(set) var pendingAutoMatchCandidateRecords: [Int: [AchievementAutoMatchCandidateRecord]] = [:]

    private let metadataFilename = "custom_achievements.json"
    private let scannedPageStatesKey = "achievement_scanned_age_page_states_v1"
    private let pendingAutoMatchCandidatesKey = "achievement_pending_auto_match_candidates_v1"
    private let stickerImageCache = NSCache<NSString, UIImage>()
    private let thumbnailImageCache = NSCache<NSString, UIImage>()

    init() {
        load()
        loadScannedPageStates()
        loadPendingAutoMatchCandidates()
    }

    func add(
        templateID: String? = nil,
        name: String,
        description: String,
        note: String,
        completedAt: Date = Date(),
        sourceImage: UIImage,
        stickerImage: UIImage? = nil,
        milestoneID: String? = nil,
        milestoneKind: AchievementMilestoneKind? = nil,
        achievedDayOffset: Int? = nil,
        sourceAssetLocalIdentifier: String? = nil,
        sourceAssetMediaSubtypeRawValue: UInt? = nil,
        livePhotoMovieURL: URL? = nil,
        creationSource: AchievementCreationSource = .manual,
        matchConfidence: Double? = nil,
        replaceAutoMatchedPeer: Bool = false
    ) throws -> CustomAchievement {
        let id = UUID()
        let originalFilename = "\(id.uuidString)-original.jpg"
        let stickerFilename = "\(id.uuidString)-sticker.png"
        let livePhotoMovieFilename = livePhotoMovieURL.map { _ in "\(id.uuidString)-live.mov" }
        let optimizedSourceImage = sourceImage.optimizedForStickerInput(maxSide: StickerGenerator.stickerInputMaxSide)
        let finalStickerImage = stickerImage ?? StickerGenerator.generateSticker(from: optimizedSourceImage)
        let originalURL = imageURL(for: originalFilename)
        let stickerURL = imageURL(for: stickerFilename)

        do {
            try saveJPEG(optimizedSourceImage, filename: originalFilename)
            try savePNG(finalStickerImage, filename: stickerFilename)
            if let livePhotoMovieURL, let livePhotoMovieFilename {
                try saveMovie(from: livePhotoMovieURL, filename: livePhotoMovieFilename)
            }

            let achievement = CustomAchievement(
                id: id,
                templateID: templateID,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "自定义成就" : name,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "记录宝宝的一个特别时刻" : description,
                note: note,
                completedAt: completedAt,
                stickerFilename: stickerFilename,
                originalFilename: originalFilename,
                milestoneID: milestoneID ?? templateID,
                milestoneKind: milestoneKind,
                achievedDayOffset: achievedDayOffset,
                sourceAssetLocalIdentifier: sourceAssetLocalIdentifier,
                sourceAssetMediaSubtypeRawValue: sourceAssetMediaSubtypeRawValue,
                livePhotoMovieFilename: livePhotoMovieFilename,
                creationSource: creationSource,
                matchConfidence: matchConfidence
            )
            var updatedAchievements = achievements
            if replaceAutoMatchedPeer {
                let removed = autoMatchedPeers(
                    in: updatedAchievements,
                    achievedDayOffset: achievedDayOffset,
                    milestoneID: milestoneID ?? templateID
                )
                updatedAchievements.removeAll { removed.map(\.id).contains($0.id) }
                removeAssetFiles(for: removed)
            }
            updatedAchievements = [achievement] + updatedAchievements
            try persist(updatedAchievements)

            achievements = updatedAchievements
            cache(finalStickerImage, for: stickerFilename)
            FamilyCloudStore.shared.scheduleUpload(reason: "achievement")
            return achievement
        } catch {
            try? FileManager.default.removeItem(at: originalURL)
            try? FileManager.default.removeItem(at: stickerURL)
            if let livePhotoMovieFilename {
                try? FileManager.default.removeItem(at: imageURL(for: livePhotoMovieFilename))
            }
            throw error
        }
    }

    func achievement(for templateID: String) -> CustomAchievement? {
        achievements.first { $0.templateID == templateID }
    }

    func achievements(onDayOffset dayOffset: Int) -> [CustomAchievement] {
        achievements
            .filter { $0.achievedDayOffset == dayOffset }
            .sorted { $0.completedAt > $1.completedAt }
    }

    func updateNote(for achievement: CustomAchievement, note: String) {
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }) else { return }
        let previousNote = achievements[index].note
        achievements[index].note = note
        do {
            try persist(achievements)
            FamilyCloudStore.shared.scheduleUpload(reason: "achievement-note")
        } catch {
            achievements[index].note = previousNote
        }
    }

    func updateImage(
        for achievement: CustomAchievement,
        sourceImage: UIImage,
        stickerImage: UIImage? = nil,
        sourceAssetLocalIdentifier: String? = nil,
        sourceAssetMediaSubtypeRawValue: UInt? = nil,
        livePhotoMovieURL: URL? = nil
    ) throws -> CustomAchievement {
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }) else {
            throw AchievementStickerError.achievementNotFound
        }

        let previousAchievement = achievements[index]
        let previousStickerImage = self.stickerImage(named: previousAchievement.stickerFilename)
        let previousOriginalImage = previousAchievement.originalFilename.flatMap { UIImage(contentsOfFile: imageURL(for: $0).path) }
        let previousLivePhotoMovieData = previousAchievement.livePhotoMovieFilename.flatMap { try? Data(contentsOf: imageURL(for: $0)) }
        let optimizedSourceImage = sourceImage.optimizedForStickerInput(maxSide: StickerGenerator.stickerInputMaxSide)
        let finalStickerImage = stickerImage ?? StickerGenerator.generateSticker(from: optimizedSourceImage)

        do {
            let originalFilename = previousAchievement.originalFilename ?? "\(previousAchievement.id.uuidString)-original.jpg"
            try saveJPEG(optimizedSourceImage, filename: originalFilename)
            try savePNG(finalStickerImage, filename: previousAchievement.stickerFilename)
            if let livePhotoMovieURL {
                let filename = previousAchievement.livePhotoMovieFilename ?? "\(previousAchievement.id.uuidString)-live.mov"
                try saveMovie(from: livePhotoMovieURL, filename: filename)
                achievements[index].livePhotoMovieFilename = filename
            }
            achievements[index].originalFilename = originalFilename
            if let sourceAssetLocalIdentifier {
                achievements[index].sourceAssetLocalIdentifier = sourceAssetLocalIdentifier
            }
            if let sourceAssetMediaSubtypeRawValue {
                achievements[index].sourceAssetMediaSubtypeRawValue = sourceAssetMediaSubtypeRawValue
            }
            try persist(achievements)
            cache(finalStickerImage, for: previousAchievement.stickerFilename)
            clearThumbnails(for: previousAchievement.stickerFilename)
            objectWillChange.send()
            FamilyCloudStore.shared.scheduleUpload(reason: "achievement-image")
            return achievements[index]
        } catch {
            if let previousStickerImage {
                try? savePNG(previousStickerImage, filename: previousAchievement.stickerFilename)
                cache(previousStickerImage, for: previousAchievement.stickerFilename)
            }
            if let originalFilename = previousAchievement.originalFilename,
               let previousOriginalImage {
                try? saveJPEG(previousOriginalImage, filename: originalFilename)
            }
            if let livePhotoMovieFilename = previousAchievement.livePhotoMovieFilename,
               let previousLivePhotoMovieData {
                try? previousLivePhotoMovieData.write(to: imageURL(for: livePhotoMovieFilename), options: [.atomic])
            }
            achievements[index] = previousAchievement
            clearThumbnails(for: previousAchievement.stickerFilename)
            throw error
        }
    }

    func delete(_ achievement: CustomAchievement) throws {
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }) else {
            return
        }

        let removedAchievement = achievements.remove(at: index)
        do {
            try persist(achievements)
            try? FileManager.default.removeItem(at: imageURL(for: removedAchievement.stickerFilename))
            if let originalFilename = removedAchievement.originalFilename {
                try? FileManager.default.removeItem(at: imageURL(for: originalFilename))
            }
            if let livePhotoMovieFilename = removedAchievement.livePhotoMovieFilename {
                try? FileManager.default.removeItem(at: imageURL(for: livePhotoMovieFilename))
            }
            stickerImageCache.removeObject(forKey: removedAchievement.stickerFilename as NSString)
            clearThumbnails(for: removedAchievement.stickerFilename)
            FamilyCloudStore.shared.markAchievementDeleted(removedAchievement.id)
        } catch {
            achievements.insert(removedAchievement, at: index)
            throw error
        }
    }

    func updateMetadata(
        for achievement: CustomAchievement,
        templateID: String?,
        name: String,
        description: String,
        note: String,
        completedAt: Date,
        milestoneID: String?,
        milestoneKind: AchievementMilestoneKind?,
        achievedDayOffset: Int?,
        creationSource: AchievementCreationSource? = nil
    ) {
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }) else { return }
        var updated = achievements[index]
        updated.templateID = templateID
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "自定义成就" : name
        updated.description = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "记录宝宝的一个特别时刻" : description
        updated.note = note
        updated.completedAt = completedAt
        updated.milestoneID = milestoneID ?? templateID
        updated.milestoneKind = milestoneKind
        updated.achievedDayOffset = achievedDayOffset
        if let creationSource {
            updated.creationSource = creationSource
        }
        achievements[index] = updated
        achievements.sort { $0.completedAt > $1.completedAt }
        do {
            try persist(achievements)
            FamilyCloudStore.shared.scheduleUpload(reason: "achievement-metadata")
        } catch {
            load()
        }
    }

    func updateScanState(pageIndex: Int, resultCount: Int) {
        scannedPageStates[pageIndex] = AchievementScanPageState(
            pageIndex: pageIndex,
            scannedAt: Date(),
            resultCount: resultCount
        )
        persistScannedPageStates()
    }

    func updatePendingAutoMatchCandidates(pageIndex: Int, records: [AchievementAutoMatchCandidateRecord]) {
        if records.isEmpty {
            pendingAutoMatchCandidateRecords[pageIndex] = nil
        } else {
            pendingAutoMatchCandidateRecords[pageIndex] = records
        }
        persistPendingAutoMatchCandidates()
    }

    func pendingAutoMatchCandidates(pageIndex: Int) -> [AchievementAutoMatchCandidateRecord] {
        pendingAutoMatchCandidateRecords[pageIndex] ?? []
    }

    func clearPendingAutoMatchCandidates(pageIndex: Int) {
        pendingAutoMatchCandidateRecords[pageIndex] = nil
        persistPendingAutoMatchCandidates()
    }

    func imageURL(for filename: String) -> URL {
        imagesDirectory.appendingPathComponent(filename)
    }

    func stickerImage(for achievement: CustomAchievement) -> UIImage? {
        stickerImage(named: achievement.stickerFilename)
    }

    func originalImage(for achievement: CustomAchievement) -> UIImage? {
        guard let originalFilename = achievement.originalFilename else { return nil }
        return UIImage(contentsOfFile: imageURL(for: originalFilename).path)
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

    func exportAchievements() -> [CustomAchievement] {
        achievements
    }

    func exportAchievementAssetURLs() -> [AchievementAssetExport] {
        achievements.map { achievement in
            AchievementAssetExport(
                achievementID: achievement.id,
                stickerFilename: achievement.stickerFilename,
                originalFilename: achievement.originalFilename,
                stickerURL: temporaryAssetURL(for: achievement.stickerFilename),
                originalURL: achievement.originalFilename.flatMap { temporaryAssetURL(for: $0) }
            )
        }
    }

    func importAchievements(_ achievements: [CustomAchievement], assetFiles: [String: AchievementAssetFiles]) throws {
        let sanitizedAchievements = sanitizedForCurrentCatalog(achievements)
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        for achievement in sanitizedAchievements {
            guard let files = assetFiles[achievement.stickerFilename] else { continue }
            if let stickerURL = files.stickerURL {
                let destination = imageURL(for: achievement.stickerFilename)
                replaceFile(at: destination, with: stickerURL)
            }
            if let originalFilename = achievement.originalFilename,
               let originalURL = files.originalURL {
                let destination = imageURL(for: originalFilename)
                replaceFile(at: destination, with: originalURL)
            }
        }
        try persist(sanitizedAchievements.sorted { $0.completedAt > $1.completedAt })
        self.achievements = sanitizedAchievements.sorted { $0.completedAt > $1.completedAt }
        stickerImageCache.removeAllObjects()
        thumbnailImageCache.removeAllObjects()
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([CustomAchievement].self, from: data) else {
            achievements = []
            return
        }
        let sanitizedAchievements = sanitizedForCurrentCatalog(decoded)
        achievements = sanitizedAchievements.sorted { $0.completedAt > $1.completedAt }
        if sanitizedAchievements.count != decoded.count {
            try? persist(achievements)
        }
    }

    private func loadScannedPageStates() {
        guard let data = UserDefaults.standard.data(forKey: scannedPageStatesKey),
              let decoded = try? JSONDecoder().decode([Int: AchievementScanPageState].self, from: data) else {
            scannedPageStates = [:]
            return
        }
        scannedPageStates = decoded
    }

    private func persistScannedPageStates() {
        guard let data = try? JSONEncoder().encode(scannedPageStates) else { return }
        UserDefaults.standard.set(data, forKey: scannedPageStatesKey)
    }

    private func loadPendingAutoMatchCandidates() {
        guard let data = UserDefaults.standard.data(forKey: pendingAutoMatchCandidatesKey),
              let decoded = try? JSONDecoder().decode([Int: [AchievementAutoMatchCandidateRecord]].self, from: data) else {
            pendingAutoMatchCandidateRecords = [:]
            return
        }
        pendingAutoMatchCandidateRecords = decoded
    }

    private func persistPendingAutoMatchCandidates() {
        guard let data = try? JSONEncoder().encode(pendingAutoMatchCandidateRecords) else { return }
        UserDefaults.standard.set(data, forKey: pendingAutoMatchCandidatesKey)
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

    private func sanitizedForCurrentCatalog(_ achievements: [CustomAchievement]) -> [CustomAchievement] {
        achievements
    }

    private func savePNG(_ image: UIImage, filename: String) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        guard let data = image.pngData() else { throw AchievementStickerError.imageEncodingFailed }
        try data.write(to: imageURL(for: filename), options: [.atomic])
    }

    private func saveJPEG(_ image: UIImage, filename: String) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        guard let data = image.jpegData(compressionQuality: 0.95) else { throw AchievementStickerError.imageEncodingFailed }
        try data.write(to: imageURL(for: filename), options: [.atomic])
    }

    private func saveMovie(from sourceURL: URL, filename: String) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let destination = imageURL(for: filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
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

    private func temporaryAssetURL(for filename: String) -> URL? {
        let sourceURL = imageURL(for: filename)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(filename)")
        do {
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    private func replaceFile(at destination: URL, with source: URL) {
        try? FileManager.default.removeItem(at: destination)
        if (try? FileManager.default.copyItem(at: source, to: destination)) == nil {
            try? FileManager.default.moveItem(at: source, to: destination)
        }
    }

    private func autoMatchedPeers(
        in achievements: [CustomAchievement],
        achievedDayOffset: Int?,
        milestoneID: String?
    ) -> [CustomAchievement] {
        guard let achievedDayOffset else { return [] }
        return achievements.filter { achievement in
            guard achievement.creationSource == .autoMatched,
                  achievement.achievedDayOffset == achievedDayOffset else {
                return false
            }
            if let milestoneID {
                return achievement.milestoneID == milestoneID || achievement.templateID == milestoneID
            }
            return achievement.milestoneID == nil && achievement.templateID == nil
        }
    }

    private func removeAssetFiles(for achievements: [CustomAchievement]) {
        for achievement in achievements {
            try? FileManager.default.removeItem(at: imageURL(for: achievement.stickerFilename))
            if let originalFilename = achievement.originalFilename {
                try? FileManager.default.removeItem(at: imageURL(for: originalFilename))
            }
            if let livePhotoMovieFilename = achievement.livePhotoMovieFilename {
                try? FileManager.default.removeItem(at: imageURL(for: livePhotoMovieFilename))
            }
            stickerImageCache.removeObject(forKey: achievement.stickerFilename as NSString)
        }
        if !achievements.isEmpty {
            thumbnailImageCache.removeAllObjects()
        }
    }

    private func cache(_ image: UIImage, for filename: String) {
        stickerImageCache.setObject(image, forKey: filename as NSString)
    }

    private func clearThumbnails(for filename: String) {
        thumbnailImageCache.removeAllObjects()
    }
}

enum AchievementStickerError: LocalizedError {
    case imageEncodingFailed
    case achievementNotFound

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "图片保存失败"
        case .achievementNotFound: return "成就不存在"
        }
    }
}

enum StickerGenerator {
    static let stickerInputMaxSide: CGFloat = 2048
    static let stickerPreviewInputMaxSide: CGFloat = 768

    enum RenderQuality {
        case preview
        case full

        var inputMaxSide: CGFloat {
            switch self {
            case .preview: return StickerGenerator.stickerPreviewInputMaxSide
            case .full: return StickerGenerator.stickerInputMaxSide
            }
        }

        var maskFeatherRadius: CGFloat {
            switch self {
            case .preview: return 0.9
            case .full: return 1.35
            }
        }
    }

    private struct InstanceStats {
        var area: Int = 0
        var sumX: Double = 0
        var sumY: Double = 0
    }

    private struct FaceAnchor {
        var x: Double
        var y: Double
        var area: Double
        var centerWeight: Double
    }

    static func generateSticker(from image: UIImage, quality: RenderQuality = .full) -> UIImage {
        guard let inputCGImage = image.normalized().cgImage else { return image }

        guard let maskedImage = generateForegroundSticker(from: inputCGImage, quality: quality) else {
            return image.normalized()
                .trimTransparentPixels()
                .addStickerOutlineAndShadow()
        }
        let trimmedImage = maskedImage.trimTransparentPixels()
        return trimmedImage.addStickerOutlineAndShadow()
    }

    private static func generateForegroundSticker(from cgImage: CGImage, quality: RenderQuality) -> UIImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            let dominantInstances = dominantInstances(in: observation, faceAnchors: faceAnchors(in: cgImage))
            let mask = try observation.generateScaledMaskForImage(forInstances: dominantInstances, from: handler)
            return apply(mask: mask, to: cgImage, featherRadius: quality.maskFeatherRadius)
        } catch {
            return nil
        }
    }

    private static func dominantInstances(in observation: VNInstanceMaskObservation, faceAnchors: [FaceAnchor]) -> IndexSet {
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
            score(for: lhs.value, centerX: centerX, centerY: centerY, maxDistance: maxDistance, faceAnchors: faceAnchors)
            < score(for: rhs.value, centerX: centerX, centerY: centerY, maxDistance: maxDistance, faceAnchors: faceAnchors)
        }?.key

        return IndexSet(integer: bestInstance ?? allInstances.first ?? 1)
    }

    private static func score(
        for stats: InstanceStats,
        centerX: Double,
        centerY: Double,
        maxDistance: Double,
        faceAnchors: [FaceAnchor]
    ) -> Double {
        guard stats.area > 0 else { return 0 }
        let centroidX = stats.sumX / Double(stats.area)
        let centroidY = stats.sumY / Double(stats.area)
        let distance = hypot(centroidX - centerX, centroidY - centerY)
        let centerWeight = 1 - min(distance / maxDistance, 1)
        let faceWeight = faceAnchors.map { anchor -> Double in
            let anchorDistance = hypot(centroidX - anchor.x, centroidY - anchor.y)
            let closeness = 1 - min(anchorDistance / maxDistance, 1)
            return closeness * (0.55 + anchor.centerWeight * 0.45)
        }.max() ?? 0
        return Double(stats.area) * (1 + centerWeight * 0.22 + faceWeight * 0.60)
    }

    private static func faceAnchors(in cgImage: CGImage) -> [FaceAnchor] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        guard (try? handler.perform([request])) != nil,
              let observations = request.results,
              !observations.isEmpty else {
            return []
        }

        let width = Double(cgImage.width)
        let height = Double(cgImage.height)
        return observations.map { face in
            let centerX = Double(face.boundingBox.midX)
            let centerY = 1.0 - Double(face.boundingBox.midY)
            let distance = hypot(centerX - 0.5, centerY - 0.5)
            return FaceAnchor(
                x: centerX * width,
                y: centerY * height,
                area: Double(face.boundingBox.width * face.boundingBox.height),
                centerWeight: max(0.0, 1.0 - distance * 1.55)
            )
        }
    }

    private static func apply(mask: CVPixelBuffer, to cgImage: CGImage, featherRadius: CGFloat) -> UIImage? {
        let context = CIContext()
        let inputImage = CIImage(cgImage: cgImage)
        var maskImage = CIImage(cvPixelBuffer: mask)
            .transformed(by: CGAffineTransform(
                scaleX: inputImage.extent.width / CGFloat(CVPixelBufferGetWidth(mask)),
                y: inputImage.extent.height / CGFloat(CVPixelBufferGetHeight(mask))
            ))
            .cropped(to: inputImage.extent)

        if featherRadius > 0 {
            maskImage = maskImage
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: featherRadius])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.18,
                    kCIInputBrightnessKey: 0.015
                ])
                .cropped(to: inputImage.extent)
        }

        let filter = CIFilter.blendWithMask()
        filter.inputImage = inputImage
        filter.backgroundImage = CIImage(color: .clear).cropped(to: inputImage.extent)
        filter.maskImage = maskImage

        guard let outputImage = filter.outputImage,
              let outputCGImage = context.createCGImage(outputImage, from: inputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: outputCGImage, scale: 1, orientation: .up)
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
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func optimizedForStickerInput(maxSide: CGFloat = StickerGenerator.stickerInputMaxSide) -> UIImage {
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
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
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
            context.cgContext.interpolationQuality = .high

            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: shadowYOffset),
                blur: shadowRadius,
                color: UIColor.black.withAlphaComponent(shadowOpacity).cgColor
            )
            normalizedImage.draw(in: imageRect)
        }
    }

    func addStickerOutlineAndShadow(
        outlineWidth: CGFloat? = nil,
        shadowRadius: CGFloat? = nil,
        shadowOpacity: CGFloat = 0.16,
        shadowYOffset: CGFloat? = nil
    ) -> UIImage {
        let normalizedImage = normalized()
        let longestSide = max(normalizedImage.size.width, normalizedImage.size.height)
        let strokeWidth = outlineWidth ?? min(max(longestSide * 0.026, 5), 14)
        let resolvedShadowRadius = shadowRadius ?? min(max(longestSide * 0.018, 6), 18)
        let resolvedShadowYOffset = shadowYOffset ?? min(max(longestSide * 0.008, 3), 9)
        let padding = strokeWidth * 2.2 + resolvedShadowRadius * 1.8
        let canvasSize = CGSize(
            width: normalizedImage.size.width + padding * 2,
            height: normalizedImage.size.height + padding * 2
        )
        let imageRect = CGRect(origin: CGPoint(x: padding, y: padding), size: normalizedImage.size)
        let silhouette = normalizedImage.tintedAlphaImage(color: .white)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { context in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))
            context.cgContext.interpolationQuality = .high

            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: resolvedShadowYOffset),
                blur: resolvedShadowRadius,
                color: UIColor.black.withAlphaComponent(shadowOpacity).cgColor
            )
            silhouette.draw(in: imageRect)
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            let steps = 20
            for step in 0..<steps {
                let angle = CGFloat(step) / CGFloat(steps) * .pi * 2
                let offset = CGPoint(x: cos(angle) * strokeWidth, y: sin(angle) * strokeWidth)
                silhouette.draw(in: imageRect.offsetBy(dx: offset.x, dy: offset.y))
            }
            let innerSteps = 12
            for step in 0..<innerSteps {
                let angle = CGFloat(step) / CGFloat(innerSteps) * .pi * 2
                let offset = CGPoint(x: cos(angle) * strokeWidth * 0.55, y: sin(angle) * strokeWidth * 0.55)
                silhouette.draw(in: imageRect.offsetBy(dx: offset.x, dy: offset.y))
            }

            normalizedImage.draw(in: imageRect)
        }
    }

    private func tintedAlphaImage(color: UIColor) -> UIImage {
        let normalizedImage = normalized()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: normalizedImage.size, format: format)
        return renderer.image { _ in
            normalizedImage.draw(in: CGRect(origin: .zero, size: normalizedImage.size))
            color.setFill()
            UIRectFillUsingBlendMode(CGRect(origin: .zero, size: normalizedImage.size), .sourceIn)
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
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            normalizedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func croppedToPreviewFrame(
        _ previewCropFrame: CGRect,
        previewSize: CGSize,
        videoGravity: AVLayerVideoGravity = .resizeAspectFill
    ) -> UIImage? {
        let normalizedImage = normalized()
        guard let cgImage = normalizedImage.cgImage,
              previewSize.width > 0,
              previewSize.height > 0,
              previewCropFrame.width > 0,
              previewCropFrame.height > 0 else {
            return nil
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale: CGFloat
        switch videoGravity {
        case .resizeAspect:
            scale = min(previewSize.width / imageSize.width, previewSize.height / imageSize.height)
        case .resize:
            let cropRect = CGRect(
                x: previewCropFrame.minX / previewSize.width * imageSize.width,
                y: previewCropFrame.minY / previewSize.height * imageSize.height,
                width: previewCropFrame.width / previewSize.width * imageSize.width,
                height: previewCropFrame.height / previewSize.height * imageSize.height
            )
            return normalizedImage.cropped(toPixelRect: cropRect)
        default:
            scale = max(previewSize.width / imageSize.width, previewSize.height / imageSize.height)
        }

        let displayedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let displayedOrigin = CGPoint(
            x: (previewSize.width - displayedSize.width) / 2,
            y: (previewSize.height - displayedSize.height) / 2
        )

        let cropRect = CGRect(
            x: (previewCropFrame.minX - displayedOrigin.x) / scale,
            y: (previewCropFrame.minY - displayedOrigin.y) / scale,
            width: previewCropFrame.width / scale,
            height: previewCropFrame.height / scale
        )
        return normalizedImage.cropped(toPixelRect: cropRect)
    }

    private func cropped(toPixelRect rect: CGRect) -> UIImage? {
        let normalizedImage = normalized()
        guard let cgImage = normalizedImage.cgImage else { return nil }

        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let cropRect = rect.integral.intersection(imageBounds)
        guard cropRect.width > 1, cropRect.height > 1,
              let cropped = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: normalizedImage.scale, orientation: .up)
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
