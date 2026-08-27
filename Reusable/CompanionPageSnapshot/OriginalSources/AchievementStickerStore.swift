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
    var achievementID: UUID
    var stickerFilename: String?
    var originalFilename: String?
    var sourceFilename: String?
    var livePhotoStillFilename: String?
    var livePhotoMovieFilename: String?
    var stickerURL: URL?
    var originalURL: URL?
    var sourceURL: URL?
    var livePhotoStillURL: URL?
    var livePhotoMovieURL: URL?
}

struct AchievementAssetExport {
    var achievementID: UUID
    var stickerFilename: String?
    var originalFilename: String?
    var sourceFilename: String?
    var livePhotoStillFilename: String?
    var livePhotoMovieFilename: String?
    var stickerURL: URL?
    var originalURL: URL?
    var sourceURL: URL?
    var livePhotoStillURL: URL?
    var livePhotoMovieURL: URL?
}

enum AchievementAssetFilenamePolicy {
    static func isValidStickerFilename(_ filename: String) -> Bool {
        isValid(filename, allowedExtensions: ["png"])
    }

    static func isValidOriginalFilename(_ filename: String) -> Bool {
        isValid(filename, allowedExtensions: ["jpg", "jpeg", "heic", "heif"])
    }

    static func isValidLivePhotoFilename(_ filename: String) -> Bool {
        isValid(filename, allowedExtensions: ["mov"])
    }

    private static func isValid(_ filename: String, allowedExtensions: Set<String>) -> Bool {
        guard !filename.isEmpty,
              filename.utf8.count <= 255,
              !filename.contains("/"),
              !filename.contains("\\"),
              !filename.contains("\0"),
              filename != ".",
              filename != ".." else {
            return false
        }
        return allowedExtensions.contains((filename as NSString).pathExtension.lowercased())
    }
}

struct AchievementCropState: Codable, Hashable {
    var normalizedOffsetX: Double = 0
    var normalizedOffsetY: Double = 0
    var scale: Double = 1
    var quarterTurns: Int = 0

    static let centered = AchievementCropState()
}

enum AchievementWatermarkStyle: String, Codable, CaseIterable, Hashable {
    case off
    case minimal
    case stacked
    case film
    case ageFocus
}

struct CustomAchievement: Identifiable, Codable, Hashable {
    let id: UUID
    var templateID: String?
    var name: String
    var description: String
    var note: String
    var completedAt: Date
    var stickerFilename: String?
    var originalFilename: String?
    var sourceFilename: String?
    var milestoneID: String?
    var milestoneKind: AchievementMilestoneKind?
    var achievedDayOffset: Int?
    var sourceAssetLocalIdentifier: String?
    var sourceAssetMediaSubtypeRawValue: UInt?
    var livePhotoMovieFilename: String?
    var livePhotoStillFilename: String?
    var creationSource: AchievementCreationSource?
    var matchConfidence: Double?
    var mediaKind: AchievementMediaKind?
    var isDayCover: Bool?
    var filterPresetID: String?
    var watermarkStyleID: String?
    var cropState: AchievementCropState?
    var sourceImageFingerprint: String?
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        templateID: String? = nil,
        name: String,
        description: String,
        note: String,
        completedAt: Date = Date(),
        stickerFilename: String? = nil,
        originalFilename: String? = nil,
        sourceFilename: String? = nil,
        milestoneID: String? = nil,
        milestoneKind: AchievementMilestoneKind? = nil,
        achievedDayOffset: Int? = nil,
        sourceAssetLocalIdentifier: String? = nil,
        sourceAssetMediaSubtypeRawValue: UInt? = nil,
        livePhotoMovieFilename: String? = nil,
        livePhotoStillFilename: String? = nil,
        creationSource: AchievementCreationSource? = nil,
        matchConfidence: Double? = nil,
        mediaKind: AchievementMediaKind? = nil,
        isDayCover: Bool? = nil,
        filterPresetID: String? = nil,
        watermarkStyleID: String? = nil,
        cropState: AchievementCropState? = nil,
        sourceImageFingerprint: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.name = name
        self.description = description
        self.note = note
        self.completedAt = completedAt
        self.stickerFilename = stickerFilename
        self.originalFilename = originalFilename
        self.sourceFilename = sourceFilename
        self.milestoneID = milestoneID
        self.milestoneKind = milestoneKind
        self.achievedDayOffset = achievedDayOffset
        self.sourceAssetLocalIdentifier = sourceAssetLocalIdentifier
        self.sourceAssetMediaSubtypeRawValue = sourceAssetMediaSubtypeRawValue
        self.livePhotoMovieFilename = livePhotoMovieFilename
        self.livePhotoStillFilename = livePhotoStillFilename
        self.creationSource = creationSource
        self.matchConfidence = matchConfidence
        self.mediaKind = mediaKind
        self.isDayCover = isDayCover
        self.filterPresetID = filterPresetID
        self.watermarkStyleID = watermarkStyleID
        self.cropState = cropState
        self.sourceImageFingerprint = sourceImageFingerprint
        self.updatedAt = updatedAt ?? Date()
    }

    var syncUpdatedAt: Date {
        updatedAt ?? completedAt
    }

    var resolvedMediaKind: AchievementMediaKind {
        mediaKind ?? .sticker
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

    var bbBucksReward: Int {
        switch self {
        case .importantDay: return 3
        case .monthly: return 2
        case .custom: return 0
        }
    }
}

enum AchievementCreationSource: String, Codable, Hashable {
    case manual
    case autoMatched
}

enum AchievementMediaKind: String, Codable, Hashable {
    case photo
    case sticker
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
    var sourceImageFingerprint: String?

    init(
        id: UUID = UUID(),
        pageIndex: Int,
        dayOffset: Int,
        date: Date,
        milestoneID: String?,
        assetLocalIdentifier: String,
        assetMediaSubtypeRawValue: UInt,
        confidence: Double,
        scoreBreakdown: AchievementAutoMatchScoreBreakdown,
        sourceImageFingerprint: String? = nil
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
        self.sourceImageFingerprint = sourceImageFingerprint
    }
}

enum AchievementImageFingerprint {
    static let duplicateDistanceThreshold = 5

    static func make(from image: UIImage) -> String? {
        let width = 9
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let cgImage = image.normalized().cgImage else { return nil }
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else {
                return false
            }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }

        var hash: UInt64 = 0
        for y in 0..<height {
            for x in 0..<(width - 1) {
                hash <<= 1
                if pixels[y * width + x] > pixels[y * width + x + 1] {
                    hash |= 1
                }
            }
        }
        return String(format: "%016llx", hash)
    }

    static func distance(_ lhs: String, _ rhs: String) -> Int? {
        guard let left = UInt64(lhs, radix: 16), let right = UInt64(rhs, radix: 16) else {
            return nil
        }
        return (left ^ right).nonzeroBitCount
    }

    static func isDuplicate(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs, let distance = distance(lhs, rhs) else { return false }
        return distance <= duplicateDistanceThreshold
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
    private let inclusiveDayNumberMigrationKey = "achievement_inclusive_day_number_migration_v1"
    private let stickerImageCache = NSCache<NSString, UIImage>()
    private let thumbnailImageCache = NSCache<NSString, UIImage>()

    init() {
        // Historical growth views can touch many assets in one session. Keep
        // image caches bounded so backgrounding cannot turn a long browsing
        // session into a jetsam-prone memory spike.
        stickerImageCache.countLimit = 48
        stickerImageCache.totalCostLimit = 24 * 1024 * 1024
        thumbnailImageCache.countLimit = 96
        thumbnailImageCache.totalCostLimit = 12 * 1024 * 1024
        load()
        loadScannedPageStates()
        loadPendingAutoMatchCandidates()
        migrateLegacyDayOffsetsToInclusiveDayNumbersIfNeeded()
    }

    func duplicateAchievement(
        sourceAssetLocalIdentifier: String?,
        sourceImageFingerprint: String?,
        excluding achievementID: UUID? = nil
    ) -> CustomAchievement? {
        achievements.first { achievement in
            guard achievement.id != achievementID else { return false }
            if let sourceAssetLocalIdentifier,
               !sourceAssetLocalIdentifier.isEmpty,
               achievement.sourceAssetLocalIdentifier == sourceAssetLocalIdentifier {
                return true
            }
            return AchievementImageFingerprint.isDuplicate(
                sourceImageFingerprint,
                achievement.sourceImageFingerprint
            )
        }
    }

    func achievementsResolvingImageFingerprints() async -> [CustomAchievement] {
        let unresolved = achievements.compactMap { achievement -> (UUID, URL)? in
            guard achievement.sourceImageFingerprint == nil,
                  let filename = achievement.sourceFilename ?? achievement.originalFilename else {
                return nil
            }
            return (achievement.id, imageURL(for: filename))
        }
        guard !unresolved.isEmpty else { return achievements }

        let resolved = await Task.detached(priority: .utility) {
            unresolved.reduce(into: [UUID: String]()) { result, item in
                guard let image = UIImage(contentsOfFile: item.1.path),
                      let fingerprint = AchievementImageFingerprint.make(from: image) else {
                    return
                }
                result[item.0] = fingerprint
            }
        }.value
        guard !resolved.isEmpty else { return achievements }

        var updatedAchievements = achievements
        for index in updatedAchievements.indices {
            if let fingerprint = resolved[updatedAchievements[index].id] {
                updatedAchievements[index].sourceImageFingerprint = fingerprint
            }
        }
        do {
            try persist(updatedAchievements)
            achievements = updatedAchievements
            SceneEntitlementStore.shared.evaluate(achievements: achievements)
        } catch {
            return achievements
        }
        return achievements
    }

    func add(
        templateID: String? = nil,
        name: String,
        description: String,
        note: String,
        completedAt: Date = Date(),
        sourceImage: UIImage,
        sourceOriginalImage: UIImage? = nil,
        stickerImage: UIImage? = nil,
        milestoneID: String? = nil,
        milestoneKind: AchievementMilestoneKind? = nil,
        achievedDayOffset: Int? = nil,
        sourceAssetLocalIdentifier: String? = nil,
        sourceAssetMediaSubtypeRawValue: UInt? = nil,
        livePhotoStillURL: URL? = nil,
        livePhotoMovieURL: URL? = nil,
        creationSource: AchievementCreationSource = .manual,
        matchConfidence: Double? = nil,
        mediaKind: AchievementMediaKind = .sticker,
        filterPresetID: String? = nil,
        watermarkStyleID: String? = nil,
        cropState: AchievementCropState? = nil,
        replaceAutoMatchedPeer: Bool = false
    ) throws -> CustomAchievement {
        guard milestoneKind != .custom else {
            throw AchievementStickerError.customAchievementsDisabled
        }
        let sourceImageFingerprint = AchievementImageFingerprint.make(from: sourceOriginalImage ?? sourceImage)
        if duplicateAchievement(
            sourceAssetLocalIdentifier: sourceAssetLocalIdentifier,
            sourceImageFingerprint: sourceImageFingerprint
        ) != nil {
            throw AchievementStickerError.imageAlreadyRecorded
        }
        let id = UUID()
        let originalFilename = "\(id.uuidString)-original.jpg"
        let sourceFilename = sourceOriginalImage.map { _ in "\(id.uuidString)-source.jpg" }
        let stickerFilename = mediaKind == .sticker ? "\(id.uuidString)-sticker.png" : nil
        let livePhotoStillFilename = livePhotoStillURL.map { "\(id.uuidString)-live.\(Self.assetExtension(for: $0, fallback: "jpg"))" }
        let livePhotoMovieFilename = livePhotoMovieURL.map { _ in "\(id.uuidString)-live.mov" }
        let squarePhotoImage = sourceImage.squareCropped(maxSide: StickerGenerator.stickerInputMaxSide)
        let finalStickerImage = mediaKind == .sticker
            ? (stickerImage ?? StickerGenerator.generateCompositeSticker(from: squarePhotoImage))
            : nil
        let normalizedName = milestoneKind == nil
            ? AppDateTimeFormat.date(completedAt)
            : (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "按日期记录" : name)
        let normalizedDescription = milestoneKind == nil
            ? "按日期留下的宝宝照片记录。"
            : (description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "按日期留下的宝宝照片记录。" : description)
        let originalURL = imageURL(for: originalFilename)

        do {
            try saveJPEG(squarePhotoImage, filename: originalFilename)
            if let sourceOriginalImage, let sourceFilename {
                try saveJPEG(sourceOriginalImage.normalized(), filename: sourceFilename)
            }
            if let finalStickerImage, let stickerFilename {
                try savePNG(finalStickerImage, filename: stickerFilename)
            }
            if let livePhotoStillURL, let livePhotoStillFilename {
                try saveAsset(from: livePhotoStillURL, filename: livePhotoStillFilename)
            }
            if let livePhotoMovieURL, let livePhotoMovieFilename {
                try saveAsset(from: livePhotoMovieURL, filename: livePhotoMovieFilename)
            }

            let achievement = CustomAchievement(
                id: id,
                templateID: templateID,
                name: normalizedName,
                description: normalizedDescription,
                note: String(note.prefix(BBBDataSafetyLimits.maxUserTextCharacters)),
                completedAt: completedAt,
                stickerFilename: stickerFilename,
                originalFilename: originalFilename,
                sourceFilename: sourceFilename,
                milestoneID: milestoneID ?? templateID,
                milestoneKind: milestoneKind,
                achievedDayOffset: achievedDayOffset,
                sourceAssetLocalIdentifier: sourceAssetLocalIdentifier,
                sourceAssetMediaSubtypeRawValue: sourceAssetMediaSubtypeRawValue,
                livePhotoMovieFilename: livePhotoMovieFilename,
                livePhotoStillFilename: livePhotoStillFilename,
                creationSource: creationSource,
                matchConfidence: matchConfidence,
                mediaKind: mediaKind,
                isDayCover: achievedDayOffset == nil ? nil : true,
                filterPresetID: filterPresetID,
                watermarkStyleID: watermarkStyleID,
                cropState: cropState,
                sourceImageFingerprint: sourceImageFingerprint
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
            if let achievedDayOffset {
                for index in updatedAchievements.indices where updatedAchievements[index].achievedDayOffset == achievedDayOffset {
                    if updatedAchievements[index].isDayCover == true {
                        updatedAchievements[index].isDayCover = false
                        updatedAchievements[index].updatedAt = Date()
                    }
                }
            }
            updatedAchievements = [achievement] + updatedAchievements
            try persist(updatedAchievements)

            achievements = updatedAchievements
            SceneEntitlementStore.shared.evaluate(achievements: achievements)
            let rewardNow = Date()
            _ = CompanionRecruitmentStore.shared.awardDailyTask(
                .dailyPhoto,
                eventDate: completedAt,
                referenceID: achievement.id.uuidString.lowercased(),
                now: rewardNow
            )
            _ = CompanionRecruitmentStore.shared.awardAchievement(
                milestoneID: achievement.milestoneID ?? achievement.templateID,
                kind: achievement.milestoneKind,
                now: rewardNow
            )
            if let finalStickerImage, let stickerFilename {
                cache(finalStickerImage, for: stickerFilename)
            }
            FamilyCloudStore.shared.scheduleUpload(reason: "achievement")
            return achievement
        } catch {
            try? FileManager.default.removeItem(at: originalURL)
            for filename in [sourceFilename, stickerFilename, livePhotoStillFilename, livePhotoMovieFilename].compactMap({ $0 }) {
                try? FileManager.default.removeItem(at: imageURL(for: filename))
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

    func coverAchievement(onDayOffset dayOffset: Int) -> CustomAchievement? {
        let dailyAchievements = achievements(onDayOffset: dayOffset)
        return dailyAchievements
            .filter { $0.isDayCover == true }
            .max(by: { $0.completedAt < $1.completedAt })
            ?? dailyAchievements.first
    }

    func setDayCover(_ achievement: CustomAchievement) throws {
        guard let storedAchievement = achievements.first(where: { $0.id == achievement.id }),
              let dayOffset = storedAchievement.achievedDayOffset else {
            throw AchievementStickerError.achievementNotFound
        }

        let previousAchievements = achievements
        var updatedAchievements = achievements
        for index in updatedAchievements.indices where updatedAchievements[index].achievedDayOffset == dayOffset {
            let nextIsDayCover = updatedAchievements[index].id == achievement.id
            if updatedAchievements[index].isDayCover != nextIsDayCover {
                updatedAchievements[index].isDayCover = nextIsDayCover
                updatedAchievements[index].updatedAt = Date()
            }
        }

        do {
            try persist(updatedAchievements)
            achievements = updatedAchievements
            FamilyCloudStore.shared.scheduleUpload(reason: "achievement-day-cover")
        } catch {
            achievements = previousAchievements
            throw error
        }
    }

    func updateNote(for achievement: CustomAchievement, note: String) {
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }) else { return }
        let previousNote = achievements[index].note
        let previousUpdatedAt = achievements[index].updatedAt
        achievements[index].note = String(note.prefix(BBBDataSafetyLimits.maxUserTextCharacters))
        achievements[index].updatedAt = Date()
        do {
            try persist(achievements)
            FamilyCloudStore.shared.scheduleUpload(reason: "achievement-note")
        } catch {
            achievements[index].note = previousNote
            achievements[index].updatedAt = previousUpdatedAt
        }
    }

    func updateImage(
        for achievement: CustomAchievement,
        sourceImage: UIImage,
        sourceOriginalImage: UIImage? = nil,
        stickerImage: UIImage? = nil,
        sourceAssetLocalIdentifier: String? = nil,
        sourceAssetMediaSubtypeRawValue: UInt? = nil,
        livePhotoStillURL: URL? = nil,
        livePhotoMovieURL: URL? = nil,
        mediaKind: AchievementMediaKind? = nil,
        filterPresetID: String? = nil,
        watermarkStyleID: String? = nil,
        cropState: AchievementCropState? = nil
    ) throws -> CustomAchievement {
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }) else {
            throw AchievementStickerError.achievementNotFound
        }

        let previousAchievement = achievements[index]
        let previousFiles = assetDataSnapshot(for: previousAchievement)
        let targetKind = mediaKind ?? previousAchievement.resolvedMediaKind
        let sourceImageFingerprint = AchievementImageFingerprint.make(from: sourceOriginalImage ?? sourceImage)
        if duplicateAchievement(
            sourceAssetLocalIdentifier: sourceAssetLocalIdentifier,
            sourceImageFingerprint: sourceImageFingerprint,
            excluding: achievement.id
        ) != nil {
            throw AchievementStickerError.imageAlreadyRecorded
        }
        let squarePhotoImage = sourceImage.squareCropped(maxSide: StickerGenerator.stickerInputMaxSide)
        let finalStickerImage = targetKind == .sticker
            ? (stickerImage ?? StickerGenerator.generateCompositeSticker(from: squarePhotoImage))
            : nil

        do {
            let originalFilename = previousAchievement.originalFilename ?? "\(previousAchievement.id.uuidString)-original.jpg"
            try saveJPEG(squarePhotoImage, filename: originalFilename)
            var updated = previousAchievement
            updated.updatedAt = Date()
            updated.originalFilename = originalFilename

            if let sourceOriginalImage {
                let filename = previousAchievement.sourceFilename ?? "\(previousAchievement.id.uuidString)-source.jpg"
                try saveJPEG(sourceOriginalImage.normalized(), filename: filename)
                updated.sourceFilename = filename
            }

            if let finalStickerImage {
                let filename = previousAchievement.stickerFilename ?? "\(previousAchievement.id.uuidString)-sticker.png"
                try savePNG(finalStickerImage, filename: filename)
                updated.stickerFilename = filename
                cache(finalStickerImage, for: filename)
            } else {
                if let previousStickerFilename = previousAchievement.stickerFilename {
                    try? FileManager.default.removeItem(at: imageURL(for: previousStickerFilename))
                    stickerImageCache.removeObject(forKey: previousStickerFilename as NSString)
                }
                updated.stickerFilename = nil
            }

            if let livePhotoStillURL {
                let filename = previousAchievement.livePhotoStillFilename
                    ?? "\(previousAchievement.id.uuidString)-live.\(Self.assetExtension(for: livePhotoStillURL, fallback: "jpg"))"
                try saveAsset(from: livePhotoStillURL, filename: filename)
                updated.livePhotoStillFilename = filename
            }
            if let livePhotoMovieURL {
                let filename = previousAchievement.livePhotoMovieFilename ?? "\(previousAchievement.id.uuidString)-live.mov"
                try saveAsset(from: livePhotoMovieURL, filename: filename)
                updated.livePhotoMovieFilename = filename
            }
            if let sourceAssetLocalIdentifier {
                updated.sourceAssetLocalIdentifier = sourceAssetLocalIdentifier
            }
            if let sourceAssetMediaSubtypeRawValue {
                updated.sourceAssetMediaSubtypeRawValue = sourceAssetMediaSubtypeRawValue
            }
            if let mediaKind {
                updated.mediaKind = mediaKind
            }
            updated.filterPresetID = filterPresetID
            updated.watermarkStyleID = watermarkStyleID
            updated.cropState = cropState
            updated.sourceImageFingerprint = sourceImageFingerprint
            achievements[index] = updated
            try persist(achievements)
            thumbnailImageCache.removeAllObjects()
            objectWillChange.send()
            FamilyCloudStore.shared.scheduleUpload(reason: "achievement-image")
            return achievements[index]
        } catch {
            restoreAssetData(previousFiles)
            achievements[index] = previousAchievement
            stickerImageCache.removeAllObjects()
            thumbnailImageCache.removeAllObjects()
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
            removeAssetFiles(for: [removedAchievement])
            FamilyCloudStore.shared.markAchievementDeleted(removedAchievement.id)
        } catch {
            achievements.insert(removedAchievement, at: index)
            throw error
        }
    }

    var autoMatchedAchievements: [CustomAchievement] {
        achievements
            .filter { $0.creationSource == .autoMatched }
            .sorted { $0.completedAt > $1.completedAt }
    }

    /// Removes only records created by the automatic matcher. Manually created
    /// achievements are deliberately excluded, even when their date or image matches.
    func deleteAutoMatchedAchievements(ids: Set<UUID>) throws -> Int {
        let removed = achievements.filter {
            ids.contains($0.id) && $0.creationSource == .autoMatched
        }
        guard !removed.isEmpty else { return 0 }

        let previousAchievements = achievements
        achievements.removeAll { achievement in
            removed.contains { $0.id == achievement.id }
        }

        do {
            try persist(achievements)
            removeAssetFiles(for: removed)
            for achievement in removed {
                FamilyCloudStore.shared.markAchievementDeleted(achievement.id)
            }
            return removed.count
        } catch {
            achievements = previousAchievements
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
        guard milestoneKind != .custom else { return }
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }) else { return }
        var updated = achievements[index]
        updated.templateID = templateID
        updated.name = milestoneKind == nil
            ? AppDateTimeFormat.date(completedAt)
            : (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "按日期记录" : name)
        updated.description = milestoneKind == nil
            ? "按日期留下的宝宝照片记录。"
            : (description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "按日期留下的宝宝照片记录。" : description)
        updated.note = note
        updated.completedAt = completedAt
        updated.milestoneID = milestoneID ?? templateID
        updated.milestoneKind = milestoneKind
        updated.achievedDayOffset = achievedDayOffset
        updated.updatedAt = Date()
        if let creationSource {
            updated.creationSource = creationSource
        }
        achievements[index] = updated
        achievements.sort { $0.completedAt > $1.completedAt }
        do {
            try persist(achievements)
            SceneEntitlementStore.shared.evaluate(achievements: achievements)
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
        var seenAssetIdentifiers: Set<String> = []
        var seenFingerprints: [String] = []
        let uniqueRecords = records.filter { record in
            guard seenAssetIdentifiers.insert(record.assetLocalIdentifier).inserted else {
                return false
            }
            if let fingerprint = record.sourceImageFingerprint {
                guard !seenFingerprints.contains(where: {
                    AchievementImageFingerprint.isDuplicate(fingerprint, $0)
                }) else {
                    return false
                }
                seenFingerprints.append(fingerprint)
            }
            return true
        }

        if uniqueRecords.isEmpty {
            pendingAutoMatchCandidateRecords[pageIndex] = nil
        } else {
            pendingAutoMatchCandidateRecords[pageIndex] = uniqueRecords
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
        guard let stickerFilename = achievement.stickerFilename else { return nil }
        return stickerImage(named: stickerFilename)
    }

    func originalImage(for achievement: CustomAchievement) -> UIImage? {
        guard let originalFilename = achievement.originalFilename else { return nil }
        return UIImage(contentsOfFile: imageURL(for: originalFilename).path)
    }

    func sourceImage(for achievement: CustomAchievement) -> UIImage? {
        guard let filename = achievement.sourceFilename else { return originalImage(for: achievement) }
        return UIImage(contentsOfFile: imageURL(for: filename).path) ?? originalImage(for: achievement)
    }

    func livePhotoResourceURLs(for achievement: CustomAchievement) -> (still: URL, movie: URL)? {
        guard let stillFilename = achievement.livePhotoStillFilename,
              let movieFilename = achievement.livePhotoMovieFilename else { return nil }
        let stillURL = imageURL(for: stillFilename)
        let movieURL = imageURL(for: movieFilename)
        guard FileManager.default.fileExists(atPath: stillURL.path),
              FileManager.default.fileExists(atPath: movieURL.path) else { return nil }
        return (stillURL, movieURL)
    }

    func thumbnailImage(for achievement: CustomAchievement, maxSide: CGFloat = 240) -> UIImage? {
        guard let stickerFilename = achievement.stickerFilename else { return nil }
        let cacheKey = "\(stickerFilename)-thumb-\(Int(maxSide))" as NSString
        if let image = thumbnailImageCache.object(forKey: cacheKey) {
            return image
        }
        guard let sticker = stickerImage(for: achievement) else { return nil }
        let thumbnail = sticker.scaledToFit(maxSide: maxSide)
        cacheThumbnail(thumbnail, for: cacheKey)
        return thumbnail
    }

    func displayImage(for achievement: CustomAchievement) -> UIImage? {
        switch achievement.resolvedMediaKind {
        case .photo:
            return originalImage(for: achievement) ?? stickerImage(for: achievement)
        case .sticker:
            return stickerImage(for: achievement) ?? originalImage(for: achievement)
        }
    }

    func displayThumbnailImage(for achievement: CustomAchievement, maxSide: CGFloat = 240) -> UIImage? {
        let sourceKey = achievement.originalFilename ?? achievement.stickerFilename ?? achievement.id.uuidString
        let cacheKey = "\(achievement.resolvedMediaKind.rawValue)-\(sourceKey)-thumb-\(Int(maxSide))" as NSString
        if let image = thumbnailImageCache.object(forKey: cacheKey) {
            return image
        }
        guard let image = displayImage(for: achievement) else { return nil }
        let thumbnail = image.scaledToFit(maxSide: maxSide)
        cacheThumbnail(thumbnail, for: cacheKey)
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
                sourceFilename: achievement.sourceFilename,
                livePhotoStillFilename: achievement.livePhotoStillFilename,
                livePhotoMovieFilename: achievement.livePhotoMovieFilename,
                stickerURL: achievement.stickerFilename.flatMap { temporaryAssetURL(for: $0) },
                originalURL: achievement.originalFilename.flatMap { temporaryAssetURL(for: $0) },
                sourceURL: achievement.sourceFilename.flatMap { temporaryAssetURL(for: $0) },
                livePhotoStillURL: achievement.livePhotoStillFilename.flatMap { temporaryAssetURL(for: $0) },
                livePhotoMovieURL: achievement.livePhotoMovieFilename.flatMap { temporaryAssetURL(for: $0) }
            )
        }
    }

    func importAchievements(_ achievements: [CustomAchievement], assetFiles: [UUID: AchievementAssetFiles]) throws {
        let boundedAchievements = Array(achievements.prefix(BBBDataSafetyLimits.maxAchievementRecords))
        let removedCustomAchievements = boundedAchievements.filter { $0.milestoneKind == .custom }
        let retainedAchievements = boundedAchievements.filter { $0.milestoneKind != .custom }
        let sanitizedAchievements = sanitizedForCurrentCatalog(retainedAchievements)
        removeAssetFiles(for: removedCustomAchievements)
        for achievement in removedCustomAchievements {
            FamilyCloudStore.shared.markAchievementDeleted(achievement.id)
        }
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        _ = importAssetFiles(assetFiles, for: sanitizedAchievements)
        try persist(sanitizedAchievements.sorted { $0.completedAt > $1.completedAt })
        self.achievements = sanitizedAchievements.sorted { $0.completedAt > $1.completedAt }
        SceneEntitlementStore.shared.evaluate(achievements: self.achievements)
        stickerImageCache.removeAllObjects()
        thumbnailImageCache.removeAllObjects()
    }

    /// Returns records whose preferred image and fallback image are both
    /// missing locally. CloudKit metadata can arrive before its asset record,
    /// so this is intentionally based on the local files rather than only on
    /// the metadata filenames.
    func missingDisplayImageAssetAchievementIDs() -> Set<UUID> {
        Set(achievements.compactMap { achievement in
            let filenames = [
                achievement.resolvedMediaKind == .photo
                    ? achievement.originalFilename
                    : achievement.stickerFilename,
                achievement.resolvedMediaKind == .photo
                    ? achievement.stickerFilename
                    : achievement.originalFilename
            ].compactMap { $0 }
            guard !filenames.isEmpty else { return nil }
            let hasLocalImage = filenames.contains {
                FileManager.default.fileExists(atPath: imageURL(for: $0).path)
            }
            return hasLocalImage ? nil : achievement.id
        })
    }

    /// Rehydrates only image assets for an already-imported metadata snapshot.
    /// Publishing a change after a successful copy makes any visible growth
    /// card rebuild its versioned media payload and retry immediately.
    @discardableResult
    func restoreAchievementAssets(_ assetFiles: [UUID: AchievementAssetFiles]) -> Int {
        let importedCount = importAssetFiles(assetFiles, for: achievements)
        guard importedCount > 0 else { return 0 }
        stickerImageCache.removeAllObjects()
        thumbnailImageCache.removeAllObjects()
        objectWillChange.send()
        return importedCount
    }

    private func load() {
        guard let values = try? metadataURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile != false,
              let fileSize = values.fileSize,
              fileSize >= 0,
              fileSize <= Int64(BBBDataSafetyLimits.maxJSONDataBytes),
              let data = try? Data(contentsOf: metadataURL),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
              let decoded = try? JSONDecoder().decode([CustomAchievement].self, from: data) else {
            achievements = []
            return
        }
        let boundedDecoded = Array(decoded.prefix(BBBDataSafetyLimits.maxAchievementRecords))
        let removedCustomAchievements = boundedDecoded.filter { $0.milestoneKind == .custom }
        let retainedAchievements = boundedDecoded.filter { $0.milestoneKind != .custom }
        let sanitizedAchievements = sanitizedForCurrentCatalog(retainedAchievements)
        if !removedCustomAchievements.isEmpty {
            removeAssetFiles(for: removedCustomAchievements)
            for achievement in removedCustomAchievements {
                FamilyCloudStore.shared.markAchievementDeleted(achievement.id)
            }
        }
        achievements = sanitizedAchievements.sorted { $0.completedAt > $1.completedAt }
        SceneEntitlementStore.shared.evaluate(achievements: achievements)
        if sanitizedAchievements.count != boundedDecoded.count {
            try? persist(achievements)
        }
    }

    private func loadScannedPageStates() {
        guard let data = UserDefaults.standard.data(forKey: scannedPageStatesKey),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
              let decoded = try? JSONDecoder().decode([Int: AchievementScanPageState].self, from: data) else {
            scannedPageStates = [:]
            return
        }
        scannedPageStates = Dictionary(
            decoded.prefix(512).map { ($0.key, $0.value) },
            uniquingKeysWith: { current, _ in current }
        )
    }

    private func persistScannedPageStates() {
        guard let data = try? JSONEncoder().encode(scannedPageStates) else { return }
        guard data.count <= BBBDataSafetyLimits.maxJSONDataBytes else { return }
        UserDefaults.standard.set(data, forKey: scannedPageStatesKey)
    }

    private func loadPendingAutoMatchCandidates() {
        guard let data = UserDefaults.standard.data(forKey: pendingAutoMatchCandidatesKey),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
              let decoded = try? JSONDecoder().decode([Int: [AchievementAutoMatchCandidateRecord]].self, from: data) else {
            pendingAutoMatchCandidateRecords = [:]
            return
        }
        pendingAutoMatchCandidateRecords = Dictionary(
            decoded.prefix(256).map { ($0.key, Array($0.value.prefix(64))) },
            uniquingKeysWith: { current, _ in current }
        )
    }

    private func persistPendingAutoMatchCandidates() {
        guard let data = try? JSONEncoder().encode(pendingAutoMatchCandidateRecords) else { return }
        guard data.count <= BBBDataSafetyLimits.maxJSONDataBytes else { return }
        UserDefaults.standard.set(data, forKey: pendingAutoMatchCandidatesKey)
    }

    /// Growth milestones now use inclusive day numbers: birth is day 1, not day 0.
    /// Existing local records keep their natural date and move their stored day number once.
    private func migrateLegacyDayOffsetsToInclusiveDayNumbersIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: inclusiveDayNumberMigrationKey) else { return }

        var didMigrate = false

        let migratedAchievements = achievements.map { achievement -> CustomAchievement in
            guard let legacyOffset = achievement.achievedDayOffset else { return achievement }
            var migrated = achievement
            migrated.achievedDayOffset = max(legacyOffset + 1, 1)
            return migrated
        }

        let migratedCandidates = pendingAutoMatchCandidateRecords.mapValues { records in
            records.map { record -> AchievementAutoMatchCandidateRecord in
                var migrated = record
                migrated.dayOffset = max(record.dayOffset + 1, 1)
                return migrated
            }
        }

        do {
            if migratedAchievements != achievements {
                try persist(migratedAchievements)
                achievements = migratedAchievements.sorted { $0.completedAt > $1.completedAt }
                SceneEntitlementStore.shared.evaluate(achievements: achievements)
                didMigrate = true
            }
            if migratedCandidates != pendingAutoMatchCandidateRecords {
                pendingAutoMatchCandidateRecords = migratedCandidates
                persistPendingAutoMatchCandidates()
                didMigrate = true
            }
            UserDefaults.standard.set(true, forKey: inclusiveDayNumberMigrationKey)
            if didMigrate {
                FamilyCloudStore.shared.scheduleUpload(reason: "achievement-inclusive-day-migration")
            }
        } catch {
            // Retry on a future launch instead of recording a partial migration as complete.
        }
    }

    private func persist(_ achievements: [CustomAchievement]) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(achievements)
        guard data.count <= BBBDataSafetyLimits.maxJSONDataBytes else {
            throw AchievementStickerError.metadataTooLarge
        }
        try data.write(to: metadataURL, options: [.atomic])
    }

    private var metadataURL: URL {
        documentsDirectory.appendingPathComponent(metadataFilename)
    }

    private var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent("AchievementStickers", isDirectory: true)
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    private func sanitizedForCurrentCatalog(_ achievements: [CustomAchievement]) -> [CustomAchievement] {
        var seenIDs: Set<UUID> = []
        var seenAssetFilenames: Set<String> = []
        var seenSourceAssetIdentifiers: Set<String> = []

        return achievements.compactMap { achievement in
            guard seenIDs.insert(achievement.id).inserted else {
                return nil
            }
            if let sourceIdentifier = achievement.sourceAssetLocalIdentifier,
               !sourceIdentifier.isEmpty,
               !seenSourceAssetIdentifiers.insert(sourceIdentifier).inserted {
                return nil
            }

            var sanitized = achievement
            sanitized.templateID = sanitized.templateID.map { String($0.prefix(BBBDataSafetyLimits.maxIdentifierCharacters)) }
            sanitized.name = String(sanitized.name.prefix(200))
            sanitized.description = String(sanitized.description.prefix(1_000))
            sanitized.note = String(sanitized.note.prefix(BBBDataSafetyLimits.maxUserTextCharacters))
            sanitized.milestoneID = sanitized.milestoneID.map { String($0.prefix(BBBDataSafetyLimits.maxIdentifierCharacters)) }
            sanitized.sourceAssetLocalIdentifier = sanitized.sourceAssetLocalIdentifier.map { String($0.prefix(BBBDataSafetyLimits.maxIdentifierCharacters)) }
            sanitized.filterPresetID = sanitized.filterPresetID.map { String($0.prefix(128)) }
            sanitized.watermarkStyleID = sanitized.watermarkStyleID.map { String($0.prefix(128)) }
            sanitized.sourceImageFingerprint = sanitized.sourceImageFingerprint.map { String($0.prefix(128)) }
            sanitized.matchConfidence = sanitized.matchConfidence.flatMap { value in
                value.isFinite ? min(max(value, 0), 1) : nil
            }
            if let stickerFilename = sanitized.stickerFilename,
               (!AchievementAssetFilenamePolicy.isValidStickerFilename(stickerFilename)
                    || !seenAssetFilenames.insert(stickerFilename).inserted) {
                sanitized.stickerFilename = nil
            }
            if let originalFilename = sanitized.originalFilename,
               (!AchievementAssetFilenamePolicy.isValidOriginalFilename(originalFilename)
                    || !seenAssetFilenames.insert(originalFilename).inserted) {
                sanitized.originalFilename = nil
            }
            if let sourceFilename = sanitized.sourceFilename,
               (!AchievementAssetFilenamePolicy.isValidOriginalFilename(sourceFilename)
                    || !seenAssetFilenames.insert(sourceFilename).inserted) {
                sanitized.sourceFilename = nil
            }
            if let livePhotoStillFilename = sanitized.livePhotoStillFilename,
               (!AchievementAssetFilenamePolicy.isValidOriginalFilename(livePhotoStillFilename)
                    || !seenAssetFilenames.insert(livePhotoStillFilename).inserted) {
                sanitized.livePhotoStillFilename = nil
            }
            if let livePhotoMovieFilename = sanitized.livePhotoMovieFilename,
               (!AchievementAssetFilenamePolicy.isValidLivePhotoFilename(livePhotoMovieFilename)
                    || !seenAssetFilenames.insert(livePhotoMovieFilename).inserted) {
                sanitized.livePhotoMovieFilename = nil
            }
            return sanitized
        }
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

    private func saveAsset(from sourceURL: URL, filename: String) throws {
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

    @discardableResult
    private func replaceFile(at destination: URL, with source: URL) -> Bool {
        try? FileManager.default.removeItem(at: destination)
        if (try? FileManager.default.copyItem(at: source, to: destination)) != nil {
            return true
        }
        return (try? FileManager.default.moveItem(at: source, to: destination)) != nil
    }

    private func importAssetFiles(
        _ assetFiles: [UUID: AchievementAssetFiles],
        for achievements: [CustomAchievement]
    ) -> Int {
        var importedCount = 0
        for achievement in achievements {
            guard let files = assetFiles[achievement.id] else { continue }
            if let stickerFilename = achievement.stickerFilename,
               let stickerURL = files.stickerURL,
               replaceFile(at: imageURL(for: stickerFilename), with: stickerURL) {
                importedCount += 1
            }
            if let originalFilename = achievement.originalFilename,
               let originalURL = files.originalURL,
               replaceFile(at: imageURL(for: originalFilename), with: originalURL) {
                importedCount += 1
            }
            if importAsset(filename: achievement.sourceFilename, sourceURL: files.sourceURL) {
                importedCount += 1
            }
            if importAsset(filename: achievement.livePhotoStillFilename, sourceURL: files.livePhotoStillURL) {
                importedCount += 1
            }
            if importAsset(filename: achievement.livePhotoMovieFilename, sourceURL: files.livePhotoMovieURL) {
                importedCount += 1
            }
        }
        return importedCount
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
            for filename in [
                achievement.stickerFilename,
                achievement.originalFilename,
                achievement.sourceFilename,
                achievement.livePhotoStillFilename,
                achievement.livePhotoMovieFilename
            ].compactMap({ $0 }) {
                try? FileManager.default.removeItem(at: imageURL(for: filename))
            }
            if let stickerFilename = achievement.stickerFilename {
                stickerImageCache.removeObject(forKey: stickerFilename as NSString)
            }
        }
        if !achievements.isEmpty {
            thumbnailImageCache.removeAllObjects()
        }
    }

    private func cache(_ image: UIImage, for filename: String) {
        stickerImageCache.setObject(
            image,
            forKey: filename as NSString,
            cost: estimatedImageCost(image)
        )
    }

    private func cacheThumbnail(_ image: UIImage, for key: NSString) {
        thumbnailImageCache.setObject(
            image,
            forKey: key,
            cost: estimatedImageCost(image)
        )
    }

    private func estimatedImageCost(_ image: UIImage) -> Int {
        let width = Double(image.size.width * image.scale)
        let height = Double(image.size.height * image.scale)
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return 1 }
        // Keep the conversion below Int's representable range even for a
        // malformed image reporting extreme dimensions.
        return Int(min(width * height * 4, Double(Int.max / 2)))
    }

    private func clearThumbnails(for filename: String) {
        thumbnailImageCache.removeAllObjects()
    }

    @discardableResult
    private func importAsset(filename: String?, sourceURL: URL?) -> Bool {
        guard let filename, let sourceURL else { return false }
        return replaceFile(at: imageURL(for: filename), with: sourceURL)
    }

    private func assetDataSnapshot(for achievement: CustomAchievement) -> [String: Data] {
        let filenames = [
            achievement.stickerFilename,
            achievement.originalFilename,
            achievement.sourceFilename,
            achievement.livePhotoStillFilename,
            achievement.livePhotoMovieFilename
        ].compactMap { $0 }
        var totalBytes = 0
        return filenames.reduce(into: [:]) { snapshot, filename in
            guard snapshot[filename] == nil,
                  let values = try? imageURL(for: filename).resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile != false,
                  let fileSize = values.fileSize,
                  fileSize >= 0,
                  fileSize <= Int64(BBBDataSafetyLimits.maxImageDataBytes),
                  totalBytes <= BBBDataSafetyLimits.maxJSONDataBytes,
                  let data = try? Data(contentsOf: imageURL(for: filename)),
                  data.count <= BBBDataSafetyLimits.maxImageDataBytes,
                  totalBytes + data.count <= BBBDataSafetyLimits.maxJSONDataBytes else {
                return
            }
            snapshot[filename] = data
            totalBytes += data.count
        }
    }

    private func restoreAssetData(_ snapshot: [String: Data]) {
        for (filename, data) in snapshot {
            try? data.write(to: imageURL(for: filename), options: [.atomic])
        }
    }

    private static func assetExtension(for url: URL, fallback: String) -> String {
        let pathExtension = url.pathExtension.lowercased()
        return pathExtension.isEmpty ? fallback : pathExtension
    }
}

enum AchievementStickerError: LocalizedError {
    case imageEncodingFailed
    case metadataTooLarge
    case achievementNotFound
    case imageAlreadyRecorded
    case customAchievementsDisabled

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "图片保存失败"
        case .metadataTooLarge: return "成就记录过大，无法保存"
        case .achievementNotFound: return "成就不存在"
        case .imageAlreadyRecorded: return "这张照片已经记录过了"
        case .customAchievementsDisabled: return "自定义照片成就已停用，请按日期或固定里程碑记录。"
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

    static func generateCompositeSticker(from image: UIImage, quality: RenderQuality = .full) -> UIImage {
        let squarePhoto = image.squareCropped(maxSide: quality.inputMaxSide)
        guard let cgImage = squarePhoto.normalized().cgImage,
              let maskedImage = generateForegroundSticker(from: cgImage, quality: quality) else {
            return squarePhoto
        }
        return maskedImage.addStickerOutlineAndShadowPreservingCanvas()
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

    func squareCropped(maxSide: CGFloat? = nil) -> UIImage {
        let normalizedImage = normalized()
        guard let cgImage = normalizedImage.cgImage else { return normalizedImage }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let side = min(width, height)
        let cropRect = CGRect(
            x: (width - side) / 2,
            y: (height - side) / 2,
            width: side,
            height: side
        ).integral

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return normalizedImage
        }

        let cropped = UIImage(cgImage: croppedCGImage, scale: normalizedImage.scale, orientation: .up)
        guard let maxSide else { return cropped }
        return cropped.scaledToFit(maxSide: maxSide)
    }

    func squareCropped(state: AchievementCropState, maxSide: CGFloat? = nil) -> UIImage {
        let rotated = rotatedByQuarterTurns(state.quarterTurns)
        let normalizedImage = rotated.normalized()
        guard let cgImage = normalizedImage.cgImage else { return normalizedImage }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let zoom = min(max(CGFloat(state.scale), 1), 4)
        let side = min(width, height) / zoom
        let maxOffsetX = max((width - side) / 2, 0)
        let maxOffsetY = max((height - side) / 2, 0)
        let centerX = width / 2 + min(max(CGFloat(state.normalizedOffsetX), -1), 1) * maxOffsetX
        let centerY = height / 2 + min(max(CGFloat(state.normalizedOffsetY), -1), 1) * maxOffsetY
        let rect = CGRect(
            x: min(max(centerX - side / 2, 0), width - side),
            y: min(max(centerY - side / 2, 0), height - side),
            width: side,
            height: side
        ).integral
        guard let croppedCGImage = cgImage.cropping(to: rect) else { return normalizedImage }
        let cropped = UIImage(cgImage: croppedCGImage, scale: normalizedImage.scale, orientation: .up)
        guard let maxSide else { return cropped }
        return cropped.scaledToFit(maxSide: maxSide)
    }

    func rotatedByQuarterTurns(_ turns: Int) -> UIImage {
        let normalizedTurns = ((turns % 4) + 4) % 4
        guard normalizedTurns != 0 else { return normalized() }
        let source = normalized()
        let swapsSides = normalizedTurns % 2 == 1
        let targetSize = swapsSides
            ? CGSize(width: source.size.height, height: source.size.width)
            : source.size
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            context.cgContext.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            context.cgContext.rotate(by: CGFloat(normalizedTurns) * .pi / 2)
            source.draw(in: CGRect(
                x: -source.size.width / 2,
                y: -source.size.height / 2,
                width: source.size.width,
                height: source.size.height
            ))
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
                color: UIColor.black.withAlphaComponent(shadowOpacity).cgColor // color-audit: allow-fixed exported sticker bitmap shadow
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
                color: UIColor.black.withAlphaComponent(shadowOpacity).cgColor // color-audit: allow-fixed exported sticker bitmap shadow
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

    func addStickerOutlineAndShadowPreservingCanvas(
        outlineWidth: CGFloat? = nil,
        shadowRadius: CGFloat? = nil,
        shadowOpacity: CGFloat = 0.14,
        shadowYOffset: CGFloat? = nil
    ) -> UIImage {
        let normalizedImage = normalized()
        let longestSide = max(normalizedImage.size.width, normalizedImage.size.height)
        let strokeWidth = outlineWidth ?? min(max(longestSide * 0.014, 3), 9)
        let resolvedShadowRadius = shadowRadius ?? min(max(longestSide * 0.012, 3), 10)
        let resolvedShadowYOffset = shadowYOffset ?? min(max(longestSide * 0.006, 1.5), 5)
        let imageRect = CGRect(origin: .zero, size: normalizedImage.size)
        let silhouette = normalizedImage.tintedAlphaImage(color: .white)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: normalizedImage.size, format: format)

        return renderer.image { context in
            UIColor.clear.setFill()
            UIRectFill(imageRect)
            context.cgContext.interpolationQuality = .high

            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: resolvedShadowYOffset),
                blur: resolvedShadowRadius,
                color: UIColor.black.withAlphaComponent(shadowOpacity).cgColor // color-audit: allow-fixed exported sticker bitmap shadow
            )
            silhouette.draw(in: imageRect)
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            let steps = 24
            for step in 0..<steps {
                let angle = CGFloat(step) / CGFloat(steps) * .pi * 2
                let offset = CGPoint(x: cos(angle) * strokeWidth, y: sin(angle) * strokeWidth)
                silhouette.draw(in: imageRect.offsetBy(dx: offset.x, dy: offset.y))
            }
            normalizedImage.draw(in: imageRect)
        }
    }

    var hasMeaningfulTransparency: Bool {
        let sampleWidth = 16
        let sampleHeight = 16
        var pixels = [UInt8](repeating: 255, count: sampleWidth * sampleHeight * 4)
        guard let cgImage = normalized().cgImage else { return false }
        return pixels.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: sampleWidth,
                    height: sampleHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: sampleWidth * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }
            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
            let samples = buffer.bindMemory(to: UInt8.self)
            return stride(from: 3, to: samples.count, by: 4).contains { samples[$0] < 245 }
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
