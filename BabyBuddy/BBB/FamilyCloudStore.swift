import CloudKit
import Foundation
import SwiftUI
import UIKit

enum FamilySharingState: Equatable {
    case localOnly
    case checkingAccount
    case iCloudUnavailable
    case syncing
    case ownerShared
    case joinedShared
    case failed(String)

    var title: String {
        switch self {
        case .localOnly: return "仅本机记录"
        case .checkingAccount: return "正在检查 iCloud"
        case .iCloudUnavailable: return "iCloud 不可用"
        case .syncing: return "正在同步"
        case .ownerShared: return "已开启家庭共享"
        case .joinedShared: return "已加入家庭共享"
        case .failed: return "同步失败"
        }
    }

    var detail: String {
        switch self {
        case .localOnly: return "邀请另一位家长后，两台手机会共同记录同一个宝宝。"
        case .checkingAccount: return "正在确认当前设备是否登录 iCloud。"
        case .iCloudUnavailable: return "请先在系统设置中登录 iCloud，并允许 iCloud Drive。"
        case .syncing: return "正在把宝宝资料、记录、成就和陪伴动物同步到 iCloud。"
        case .ownerShared: return "你创建了这个宝宝空间，可以继续邀请另一位家长。"
        case .joinedShared: return "你正在和另一位家长共同记录这个宝宝。"
        case .failed(let message): return message
        }
    }
}

struct FamilyCloudSnapshot: Codable {
    var profile: BabyProfileData
    var feedingSessions: [FeedingSession]
    var careRecords: [CareRecord]
    var growthMetricRecords: [GrowthMetricRecord]?
    var achievements: [CustomAchievement]
    var subjectiveStateCheckIns: [SubjectiveStateCheckIn]?
    var deletedFeedingSessionIDs: [UUID]?
    var deletedCareRecordIDs: [UUID]?
    var deletedGrowthMetricRecordIDs: [UUID]?
    var deletedAchievementIDs: [UUID]?
    var deletedSubjectiveStateCheckInIDs: [UUID]?
    var selectedCompanionID: String
    var temperamentResult: BabyTemperamentResult?
    var recruitment: CompanionRecruitmentSnapshot?
    var sceneEntitlements: [SceneEntitlement]?
    var updatedAt: Date
}

struct FamilyCloudShareSheet: UIViewControllerRepresentable {
    let controller: UICloudSharingController

    func makeUIViewController(context: Context) -> UICloudSharingController {
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? {
            "BabyBuddy 宝宝空间"
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {}
    }
}

@MainActor
final class FamilyCloudStore: ObservableObject {
    static let shared = FamilyCloudStore()

    @Published private(set) var state: FamilySharingState = .localOnly
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var isConfigured = false

    private enum RecordType {
        static let babySpace = "BabySpace"
        static let achievementAsset = "AchievementAsset"
    }

    private enum Field {
        static let snapshot = "snapshot"
        static let snapshotAsset = "snapshotAsset"
        static let updatedAt = "updatedAt"
        static let title = "title"
        static let babySpace = "babySpace"
        static let stickerFilename = "stickerFilename"
        static let originalFilename = "originalFilename"
        static let sourceFilename = "sourceFilename"
        static let livePhotoStillFilename = "livePhotoStillFilename"
        static let livePhotoMovieFilename = "livePhotoMovieFilename"
        static let stickerAsset = "stickerAsset"
        static let originalAsset = "originalAsset"
        static let sourceAsset = "sourceAsset"
        static let livePhotoStillAsset = "livePhotoStillAsset"
        static let livePhotoMovieAsset = "livePhotoMovieAsset"
    }

    private struct StoredLocator: Codable {
        var recordName: String
        var zoneName: String
        var ownerName: String
        var isOwner: Bool

        var zoneID: CKRecordZone.ID {
            CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        }

        var recordID: CKRecord.ID {
            CKRecord.ID(recordName: recordName, zoneID: zoneID)
        }
    }

    private lazy var container = CKContainer(identifier: "iCloud.v.babybuddy")
    private let localLocatorKey = "family_cloud_baby_space_locator_v1"
    private let localSnapshotUpdatedAtKey = "family_cloud_local_snapshot_updated_at_v1"
    private let localSnapshotDirtyKey = "family_cloud_local_snapshot_dirty_v1"
    private let deletedFeedingSessionIDsKey = "family_cloud_deleted_feeding_session_ids_v1"
    private let deletedCareRecordIDsKey = "family_cloud_deleted_care_record_ids_v1"
    private let deletedGrowthMetricRecordIDsKey = "family_cloud_deleted_growth_metric_record_ids_v1"
    private let deletedAchievementIDsKey = "family_cloud_deleted_achievement_ids_v1"
    private let deletedSubjectiveStateCheckInIDsKey = "family_cloud_deleted_subjective_state_check_in_ids_v1"
    private let zoneName = "BabyBuddySharedZone"
    private let syncDebounce: TimeInterval = 1.4
    private let snapshotTemporaryDirectoryName = "BabyBuddyCloudSnapshots"
    private let maxSnapshotByteCount = 10 * 1024 * 1024
    private let maxAchievementAssetByteCount = 30 * 1024 * 1024
    private let cloudModifyBatchSize = 200
    private let maxSyncRetryAttempts = 3

    private weak var feedingStore: FeedingStore?
    private weak var activityStore: ActivityStore?
    private weak var growthMetricStore: GrowthMetricStore?
    private weak var achievementStore: AchievementStickerStore?
    private weak var companionStore: CompanionStore?
    private weak var temperamentStore: TemperamentProfileStore?
    private weak var subjectiveStateStore: SubjectiveStateStore?
    private var profileStore: BabyProfileStore?
    private var scheduledUploadTask: Task<Void, Never>?
    private var isApplyingRemoteSnapshot = false
    private var isSyncInProgress = false
    private var needsFollowUpSync = false
    private var localMutationRevision: UInt64 = 0
    private var syncRetryAttempt = 0

    private init() {}

    var isApplyingRemoteChanges: Bool {
        isApplyingRemoteSnapshot
    }

    private static var canUseCloudKitContainer: Bool {
        #if targetEnvironment(simulator) && arch(x86_64)
        false
        #else
        true
        #endif
    }

    func configure(
        profileStore: BabyProfileStore,
        feedingStore: FeedingStore,
        activityStore: ActivityStore,
        growthMetricStore: GrowthMetricStore,
        achievementStore: AchievementStickerStore,
        companionStore: CompanionStore,
        temperamentStore: TemperamentProfileStore,
        subjectiveStateStore: SubjectiveStateStore
    ) {
        self.profileStore = profileStore
        self.feedingStore = feedingStore
        self.activityStore = activityStore
        self.growthMetricStore = growthMetricStore
        self.achievementStore = achievementStore
        self.companionStore = companionStore
        self.temperamentStore = temperamentStore
        self.subjectiveStateStore = subjectiveStateStore
        isConfigured = true
    }

    func bootstrapIfNeeded() async {
        guard isConfigured else { return }
        guard Self.canUseCloudKitContainer else {
            state = .iCloudUnavailable
            return
        }
        state = .checkingAccount
        do {
            guard try await accountIsAvailable() else {
                state = .iCloudUnavailable
                return
            }
            if let locator = storedLocator() {
                state = locator.isOwner ? .ownerShared : .joinedShared
                await syncNow()
            } else {
                state = .localOnly
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func makeInviteController() async throws -> UICloudSharingController {
        guard isConfigured else { throw FamilyCloudError.notConfigured }
        guard Self.canUseCloudKitContainer else { throw FamilyCloudError.iCloudUnavailable }
        guard try await accountIsAvailable() else { throw FamilyCloudError.iCloudUnavailable }
        state = .syncing

        let expectedRevision = localMutationRevision
        let locator = try await ensureOwnerBabySpace()
        let snapshot = try snapshotForUpload()
        let rootRecord = try await upsertSnapshotRecord(locator: locator, snapshot: snapshot)
        try await upsertAchievementAssets(locator: locator, rootRecord: rootRecord, database: container.privateCloudDatabase)
        let share = try await existingOrNewShare(for: rootRecord)
        share[CKShare.SystemFieldKey.title] = "\(snapshot.profile.name) 的 BabyBuddy" as CKRecordValue
        try await save(records: [rootRecord, share], in: container.privateCloudDatabase)

        saveLocator(locator)
        finishSnapshotSync(snapshot.updatedAt, expectedRevision: expectedRevision)
        lastSyncAt = Date()
        state = .ownerShared
        return UICloudSharingController(share: share, container: container)
    }

    func syncNow() async {
        guard isConfigured, storedLocator() != nil, Self.canUseCloudKitContainer else { return }
        if isSyncInProgress {
            needsFollowUpSync = true
            return
        }

        isSyncInProgress = true
        defer { isSyncInProgress = false }
        repeat {
            needsFollowUpSync = false
            await performSingleSync()
        } while needsFollowUpSync && !Task.isCancelled
    }

    private func performSingleSync() async {
        guard let locator = storedLocator() else { return }
        let expectedRevision = localMutationRevision
        state = .syncing
        do {
            let database = locator.isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase
            let localUpdatedAt = storedLocalSnapshotUpdatedAt() ?? .distantPast
            let remoteRecord = try await fetchOptionalRecord(locator.recordID, from: database)

            if let remoteRecord {
                let remoteSnapshot = try decodeSnapshot(from: remoteRecord)
                guard localMutationRevision == expectedRevision else {
                    throw FamilyCloudError.localDataChangedDuringSync
                }
                let hasLocalChanges = localSnapshotIsDirty()
                if remoteSnapshot.updatedAt > localUpdatedAt, !hasLocalChanges {
                    try await applyRemoteSnapshot(
                        remoteSnapshot,
                        rootRecord: remoteRecord,
                        database: database,
                        expectedRevision: expectedRevision
                    )
                    finishSnapshotSync(remoteSnapshot.updatedAt, expectedRevision: expectedRevision)
                } else if remoteSnapshot.updatedAt > localUpdatedAt {
                    let localSnapshot = try currentSnapshot(updatedAt: localUpdatedAt)
                    let mergedSnapshot = mergeSnapshots(
                        local: localSnapshot,
                        remote: remoteSnapshot,
                        preferRemoteFields: true
                    )
                    try await applyAndSaveIfNeeded(
                        mergedSnapshot,
                        remoteSnapshot: remoteSnapshot,
                        rootRecord: remoteRecord,
                        locator: locator,
                        database: database,
                        expectedRevision: expectedRevision
                    )
                } else if localUpdatedAt > remoteSnapshot.updatedAt {
                    let localSnapshot = try currentSnapshot(updatedAt: localUpdatedAt)
                    let mergedSnapshot = mergeSnapshots(
                        local: localSnapshot,
                        remote: remoteSnapshot,
                        preferRemoteFields: false
                    )
                    try await applyRemoteSnapshot(
                        mergedSnapshot,
                        rootRecord: remoteRecord,
                        database: database,
                        expectedRevision: expectedRevision
                    )
                    _ = try await saveSnapshot(mergedSnapshot, rootRecord: remoteRecord, database: database)
                    try await upsertAchievementAssets(locator: locator, rootRecord: remoteRecord, database: database)
                    finishSnapshotSync(mergedSnapshot.updatedAt, expectedRevision: expectedRevision)
                }
            } else if locator.isOwner {
                let localSnapshot = try snapshotForUpload()
                let rootRecord = CKRecord(recordType: RecordType.babySpace, recordID: locator.recordID)
                _ = try await saveSnapshot(localSnapshot, rootRecord: rootRecord, database: database)
                try await upsertAchievementAssets(locator: locator, rootRecord: rootRecord, database: database)
                finishSnapshotSync(localSnapshot.updatedAt, expectedRevision: expectedRevision)
            } else {
                throw FamilyCloudError.recordNotFound
            }

            lastSyncAt = Date()
            syncRetryAttempt = 0
            state = locator.isOwner ? .ownerShared : .joinedShared
        } catch FamilyCloudError.localDataChangedDuringSync {
            needsFollowUpSync = true
        } catch {
            state = .failed(error.localizedDescription)
            scheduleRetryIfNeeded(for: error)
        }
    }

    func scheduleUpload(reason _: String = "") {
        guard isConfigured, !isApplyingRemoteSnapshot else { return }
        localMutationRevision &+= 1
        syncRetryAttempt = 0
        setLocalSnapshotUpdatedAt(Date())
        setLocalSnapshotDirty(true)
        guard storedLocator() != nil else { return }
        scheduledUploadTask?.cancel()
        scheduledUploadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(self.syncDebounce * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self.syncNow()
        }
    }

    private func scheduleRetryIfNeeded(for error: Error) {
        guard syncRetryAttempt < maxSyncRetryAttempts,
              let delay = retryDelay(for: error) else {
            return
        }
        syncRetryAttempt += 1
        scheduledUploadTask?.cancel()
        scheduledUploadTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            await self.syncNow()
        }
    }

    private func retryDelay(for error: Error) -> TimeInterval? {
        guard let cloudError = error as? CKError else { return nil }
        let serverDelay = (cloudError.userInfo[CKErrorRetryAfterKey] as? NSNumber)?.doubleValue
        switch cloudError.code {
        case .networkUnavailable,
             .networkFailure,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy,
             .serverRecordChanged,
             .partialFailure:
            let exponentialDelay = pow(2, Double(syncRetryAttempt + 1))
            return max(serverDelay ?? 0, exponentialDelay)
        default:
            return nil
        }
    }

    func markFeedingSessionDeleted(_ id: UUID) {
        addDeletedID(id, key: deletedFeedingSessionIDsKey)
        scheduleUpload(reason: "feeding-delete")
    }

    func markCareRecordDeleted(_ id: UUID) {
        addDeletedID(id, key: deletedCareRecordIDsKey)
        scheduleUpload(reason: "care-delete")
    }

    func markGrowthMetricRecordDeleted(_ id: UUID) {
        addDeletedID(id, key: deletedGrowthMetricRecordIDsKey)
        scheduleUpload(reason: "growth-delete")
    }

    func markAchievementDeleted(_ id: UUID) {
        addDeletedID(id, key: deletedAchievementIDsKey)
        scheduleUpload(reason: "achievement-delete")
    }

    func markSubjectiveStateCheckInDeleted(_ id: UUID) {
        addDeletedID(id, key: deletedSubjectiveStateCheckInIDsKey)
        scheduleUpload(reason: "subjective-state-delete")
    }

    func acceptShare(metadata: CKShare.Metadata) async {
        guard Self.canUseCloudKitContainer else {
            state = .iCloudUnavailable
            return
        }
        state = .syncing
        do {
            try await accept(metadata: metadata)
            guard let rootID = metadata.hierarchicalRootRecordID else {
                throw FamilyCloudError.recordNotFound
            }
            let locator = StoredLocator(
                recordName: rootID.recordName,
                zoneName: rootID.zoneID.zoneName,
                ownerName: rootID.zoneID.ownerName,
                isOwner: false
            )
            saveLocator(locator)
            setLocalSnapshotUpdatedAt(.distantPast)
            state = .joinedShared
            await syncNow()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func ensureOwnerBabySpace() async throws -> StoredLocator {
        if let locator = storedLocator(), locator.isOwner {
            return locator
        }
        try await ensureCustomZone()
        let recordName = UUID().uuidString
        let locator = StoredLocator(
            recordName: recordName,
            zoneName: zoneName,
            ownerName: CKCurrentUserDefaultName,
            isOwner: true
        )
        saveLocator(locator)
        return locator
    }

    private func snapshotForUpload() throws -> FamilyCloudSnapshot {
        try currentSnapshot(updatedAt: uploadSnapshotUpdatedAt())
    }

    private func currentSnapshot(updatedAt: Date) throws -> FamilyCloudSnapshot {
        guard let profileStore,
              let feedingStore,
              let activityStore,
              let growthMetricStore,
              let achievementStore,
              let companionStore,
              let subjectiveStateStore else {
            throw FamilyCloudError.notConfigured
        }

        let deletedFeedingSessionIDs = deletedFeedingSessionIDs()
        let deletedCareRecordIDs = deletedCareRecordIDs()
        let deletedGrowthMetricRecordIDs = deletedGrowthMetricRecordIDs()
        let deletedAchievementIDs = deletedAchievementIDs()
        let deletedSubjectiveStateCheckInIDs = deletedSubjectiveStateCheckInIDs()

        return FamilyCloudSnapshot(
            profile: profileStore.currentProfile,
            feedingSessions: feedingStore.exportSessions()
                .filter { !deletedFeedingSessionIDs.contains($0.id) },
            careRecords: activityStore.exportCareRecords()
                .filter { !deletedCareRecordIDs.contains($0.id) },
            growthMetricRecords: growthMetricStore.exportRecords()
                .filter { !deletedGrowthMetricRecordIDs.contains($0.id) },
            achievements: achievementStore.exportAchievements()
                .filter { !deletedAchievementIDs.contains($0.id) },
            subjectiveStateCheckIns: subjectiveStateStore.exportCheckIns()
                .filter { !deletedSubjectiveStateCheckInIDs.contains($0.id) },
            deletedFeedingSessionIDs: sortedIDs(deletedFeedingSessionIDs),
            deletedCareRecordIDs: sortedIDs(deletedCareRecordIDs),
            deletedGrowthMetricRecordIDs: sortedIDs(deletedGrowthMetricRecordIDs),
            deletedAchievementIDs: sortedIDs(deletedAchievementIDs),
            deletedSubjectiveStateCheckInIDs: sortedIDs(deletedSubjectiveStateCheckInIDs),
            selectedCompanionID: companionStore.selectedID,
            temperamentResult: temperamentStore?.exportResult(),
            recruitment: CompanionRecruitmentStore.shared.exportSnapshot(),
            sceneEntitlements: SceneEntitlementStore.shared.exportEntitlements(),
            updatedAt: updatedAt
        )
    }

    private func applyRemoteSnapshot(
        _ snapshot: FamilyCloudSnapshot,
        rootRecord: CKRecord,
        database: CKDatabase,
        expectedRevision: UInt64
    ) async throws {
        guard let profileStore,
              let feedingStore,
              let activityStore,
              let growthMetricStore,
              let achievementStore,
              let companionStore,
              let subjectiveStateStore else {
            throw FamilyCloudError.notConfigured
        }
        let assets = try await fetchAchievementAssetFiles(rootRecord: rootRecord, database: database)
        guard localMutationRevision == expectedRevision else {
            throw FamilyCloudError.localDataChangedDuringSync
        }
        let deletedFeedingSessionIDs = Set(snapshot.deletedFeedingSessionIDs ?? [])
        let deletedCareRecordIDs = Set(snapshot.deletedCareRecordIDs ?? [])
        let deletedGrowthMetricRecordIDs = Set(snapshot.deletedGrowthMetricRecordIDs ?? [])
        let deletedAchievementIDs = Set(snapshot.deletedAchievementIDs ?? [])
        let deletedSubjectiveStateCheckInIDs = Set(snapshot.deletedSubjectiveStateCheckInIDs ?? [])
        isApplyingRemoteSnapshot = true
        defer { isApplyingRemoteSnapshot = false }
        setDeletedFeedingSessionIDs(deletedFeedingSessionIDs)
        setDeletedCareRecordIDs(deletedCareRecordIDs)
        setDeletedGrowthMetricRecordIDs(deletedGrowthMetricRecordIDs)
        setDeletedAchievementIDs(deletedAchievementIDs)
        setDeletedSubjectiveStateCheckInIDs(deletedSubjectiveStateCheckInIDs)
        profileStore.importProfile(snapshot.profile)
        feedingStore.importSessions(
            snapshot.feedingSessions.filter { !deletedFeedingSessionIDs.contains($0.id) }
        )
        activityStore.importCareRecords(
            snapshot.careRecords.filter { !deletedCareRecordIDs.contains($0.id) }
        )
        growthMetricStore.importRecords(
            (snapshot.growthMetricRecords ?? []).filter { !deletedGrowthMetricRecordIDs.contains($0.id) }
        )
        if let subjectiveStateCheckIns = snapshot.subjectiveStateCheckIns {
            subjectiveStateStore.importCheckIns(
                subjectiveStateCheckIns.filter { !deletedSubjectiveStateCheckInIDs.contains($0.id) }
            )
        }
        companionStore.importSelectedID(snapshot.selectedCompanionID)
        temperamentStore?.importResult(snapshot.temperamentResult)
        if let recruitment = snapshot.recruitment {
            CompanionRecruitmentStore.shared.importSnapshot(recruitment)
        }
        if let sceneEntitlements = snapshot.sceneEntitlements {
            SceneEntitlementStore.shared.importEntitlements(sceneEntitlements)
        }
        try achievementStore.importAchievements(
            snapshot.achievements.filter { !deletedAchievementIDs.contains($0.id) },
            assetFiles: assets
        )
    }

    private func applyAndSaveIfNeeded(
        _ mergedSnapshot: FamilyCloudSnapshot,
        remoteSnapshot: FamilyCloudSnapshot,
        rootRecord: CKRecord,
        locator: StoredLocator,
        database: CKDatabase,
        expectedRevision: UInt64
    ) async throws {
        if snapshotPayloadEquals(mergedSnapshot, remoteSnapshot) {
            try await applyRemoteSnapshot(
                remoteSnapshot,
                rootRecord: rootRecord,
                database: database,
                expectedRevision: expectedRevision
            )
            finishSnapshotSync(remoteSnapshot.updatedAt, expectedRevision: expectedRevision)
            return
        }

        try await applyRemoteSnapshot(
            mergedSnapshot,
            rootRecord: rootRecord,
            database: database,
            expectedRevision: expectedRevision
        )
        _ = try await saveSnapshot(mergedSnapshot, rootRecord: rootRecord, database: database)
        try await upsertAchievementAssets(locator: locator, rootRecord: rootRecord, database: database)
        finishSnapshotSync(mergedSnapshot.updatedAt, expectedRevision: expectedRevision)
    }

    private func finishSnapshotSync(_ updatedAt: Date, expectedRevision: UInt64) {
        guard localMutationRevision == expectedRevision else {
            needsFollowUpSync = true
            return
        }
        setLocalSnapshotUpdatedAt(updatedAt)
        setLocalSnapshotDirty(false)
    }

    private func mergeSnapshots(
        local: FamilyCloudSnapshot,
        remote: FamilyCloudSnapshot,
        preferRemoteFields: Bool
    ) -> FamilyCloudSnapshot {
        let fieldSource = preferRemoteFields ? remote : local
        let deletedFeedingSessionIDs = Set(local.deletedFeedingSessionIDs ?? [])
            .union(remote.deletedFeedingSessionIDs ?? [])
        let deletedCareRecordIDs = Set(local.deletedCareRecordIDs ?? [])
            .union(remote.deletedCareRecordIDs ?? [])
        let deletedGrowthMetricRecordIDs = Set(local.deletedGrowthMetricRecordIDs ?? [])
            .union(remote.deletedGrowthMetricRecordIDs ?? [])
        let deletedAchievementIDs = Set(local.deletedAchievementIDs ?? [])
            .union(remote.deletedAchievementIDs ?? [])
        let deletedSubjectiveStateCheckInIDs = Set(local.deletedSubjectiveStateCheckInIDs ?? [])
            .union(remote.deletedSubjectiveStateCheckInIDs ?? [])
        return FamilyCloudSnapshot(
            profile: fieldSource.profile,
            feedingSessions: mergedByID(
                local.feedingSessions,
                remote.feedingSessions,
                deletedIDs: deletedFeedingSessionIDs,
                preferRemote: preferRemoteFields,
                sortedBy: { $0.createdAt > $1.createdAt }
            ),
            careRecords: mergedByID(
                local.careRecords,
                remote.careRecords,
                deletedIDs: deletedCareRecordIDs,
                preferRemote: preferRemoteFields,
                sortedBy: { $0.recordedAt > $1.recordedAt }
            ),
            growthMetricRecords: mergedByID(
                local.growthMetricRecords ?? [],
                remote.growthMetricRecords ?? [],
                deletedIDs: deletedGrowthMetricRecordIDs,
                preferRemote: preferRemoteFields,
                sortedBy: { $0.recordedAt > $1.recordedAt }
            ),
            achievements: mergedByID(
                local.achievements,
                remote.achievements,
                deletedIDs: deletedAchievementIDs,
                preferRemote: preferRemoteFields,
                sortedBy: { $0.completedAt > $1.completedAt }
            ),
            subjectiveStateCheckIns: mergedSubjectiveStateCheckIns(
                local.subjectiveStateCheckIns ?? [],
                remote.subjectiveStateCheckIns ?? [],
                deletedIDs: deletedSubjectiveStateCheckInIDs
            ),
            deletedFeedingSessionIDs: sortedIDs(deletedFeedingSessionIDs),
            deletedCareRecordIDs: sortedIDs(deletedCareRecordIDs),
            deletedGrowthMetricRecordIDs: sortedIDs(deletedGrowthMetricRecordIDs),
            deletedAchievementIDs: sortedIDs(deletedAchievementIDs),
            deletedSubjectiveStateCheckInIDs: sortedIDs(deletedSubjectiveStateCheckInIDs),
            selectedCompanionID: fieldSource.selectedCompanionID,
            temperamentResult: fieldSource.temperamentResult,
            recruitment: mergeRecruitmentSnapshots(
                local.recruitment,
                remote.recruitment,
                preferRemote: preferRemoteFields
            ),
            sceneEntitlements: mergedEntitlements(
                local.sceneEntitlements ?? [],
                remote.sceneEntitlements ?? []
            ),
            updatedAt: nextSnapshotUpdatedAt(local.updatedAt, remote.updatedAt)
        )
    }

    private func mergeRecruitmentSnapshots(
        _ local: CompanionRecruitmentSnapshot?,
        _ remote: CompanionRecruitmentSnapshot?,
        preferRemote: Bool
    ) -> CompanionRecruitmentSnapshot? {
        guard let local else { return remote }
        guard let remote else { return local }
        let fieldSource = preferRemote ? remote : local
        var transactionByID = Dictionary(uniqueKeysWithValues: local.transactions.map { ($0.id, $0) })
        for transaction in remote.transactions {
            transactionByID[transaction.id] = transactionByID[transaction.id] ?? transaction
        }
        var friendshipValues = local.friendshipValues
        for (companionID, value) in remote.friendshipValues {
            friendshipValues[companionID] = max(friendshipValues[companionID] ?? 0, value)
        }
        let mergedTransactions = transactionByID.values.sorted { $0.createdAt < $1.createdAt }
        let balanceAnchor = max(recruitmentBalanceAnchor(local), recruitmentBalanceAnchor(remote))
        let mergedBalance = max(
            balanceAnchor
                + mergedTransactions.reduce(0) { $0 + $1.amount }
                - friendshipValues.values.reduce(0, +),
            0
        )
        return CompanionRecruitmentSnapshot(
            bbBucks: mergedBalance,
            balanceAnchor: balanceAnchor,
            friendshipValues: friendshipValues,
            recruitedIDs: local.recruitedIDs.union(remote.recruitedIDs),
            transactions: mergedTransactions,
            relationshipState: fieldSource.relationshipState,
            historicalImportSettlement: HistoricalImportSettlement(
                awardedAmount: max(
                    local.historicalImportSettlement.awardedAmount,
                    remote.historicalImportSettlement.awardedAmount
                ),
                importFingerprints: local.historicalImportSettlement.importFingerprints
                    .union(remote.historicalImportSettlement.importFingerprints)
            )
        )
    }

    private func recruitmentBalanceAnchor(_ snapshot: CompanionRecruitmentSnapshot) -> Int {
        snapshot.balanceAnchor
            ?? snapshot.bbBucks
                + snapshot.friendshipValues.values.reduce(0, +)
                - snapshot.transactions.reduce(0) { $0 + $1.amount }
    }

    private func mergedEntitlements(
        _ local: [SceneEntitlement],
        _ remote: [SceneEntitlement]
    ) -> [SceneEntitlement] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for entitlement in remote {
            byID[entitlement.id] = byID[entitlement.id] ?? entitlement
        }
        return byID.values.sorted { $0.awardedAt < $1.awardedAt }
    }

    private func mergedByID<Item: Identifiable>(
        _ localItems: [Item],
        _ remoteItems: [Item],
        deletedIDs: Set<Item.ID>,
        preferRemote: Bool,
        sortedBy areInIncreasingOrder: (Item, Item) -> Bool
    ) -> [Item] where Item.ID: Hashable {
        var merged: [Item.ID: Item] = [:]
        for item in localItems where !deletedIDs.contains(item.id) {
            merged[item.id] = item
        }
        for item in remoteItems where !deletedIDs.contains(item.id) && (preferRemote || merged[item.id] == nil) {
            merged[item.id] = item
        }
        return Array(merged.values).sorted(by: areInIncreasingOrder)
    }

    private func mergedSubjectiveStateCheckIns(
        _ localItems: [SubjectiveStateCheckIn],
        _ remoteItems: [SubjectiveStateCheckIn],
        deletedIDs: Set<UUID>
    ) -> [SubjectiveStateCheckIn] {
        var merged: [UUID: SubjectiveStateCheckIn] = [:]
        for item in localItems where !deletedIDs.contains(item.id) {
            merged[item.id] = item
        }
        for item in remoteItems where !deletedIDs.contains(item.id) {
            guard let current = merged[item.id] else {
                merged[item.id] = item
                continue
            }
            if item.updatedAt > current.updatedAt {
                merged[item.id] = item
            }
        }
        return merged.values.sorted { $0.recordedAt > $1.recordedAt }
    }

    private func sortedIDs(_ ids: Set<UUID>) -> [UUID] {
        ids.sorted { $0.uuidString < $1.uuidString }
    }

    private func nextSnapshotUpdatedAt(_ lhs: Date, _ rhs: Date) -> Date {
        let latestKnown = max(lhs, rhs)
        return max(Date(), latestKnown.addingTimeInterval(0.001))
    }

    private func snapshotPayloadEquals(_ lhs: FamilyCloudSnapshot, _ rhs: FamilyCloudSnapshot) -> Bool {
        var lhsPayload = lhs
        var rhsPayload = rhs
        lhsPayload.updatedAt = .distantPast
        rhsPayload.updatedAt = .distantPast
        let encoder = JSONEncoder()
        return (try? encoder.encode(lhsPayload)) == (try? encoder.encode(rhsPayload))
    }

    private func upsertSnapshotRecord(locator: StoredLocator, snapshot: FamilyCloudSnapshot) async throws -> CKRecord {
        let database = container.privateCloudDatabase
        let record = (try? await fetchRecord(locator.recordID, from: database))
            ?? CKRecord(recordType: RecordType.babySpace, recordID: locator.recordID)
        return try await saveSnapshot(snapshot, rootRecord: record, database: database)
    }

    private func saveSnapshot(_ snapshot: FamilyCloudSnapshot, rootRecord: CKRecord, database: CKDatabase) async throws -> CKRecord {
        let data = try JSONEncoder().encode(snapshot)
        let snapshotURL = try writeTemporarySnapshotAsset(data)
        rootRecord[Field.snapshot] = nil
        rootRecord[Field.snapshotAsset] = CKAsset(fileURL: snapshotURL)
        rootRecord[Field.updatedAt] = snapshot.updatedAt as CKRecordValue
        rootRecord[Field.title] = snapshot.profile.name as CKRecordValue
        do {
            try await save(records: [rootRecord], in: database)
            try? FileManager.default.removeItem(at: snapshotURL)
            return rootRecord
        } catch {
            try? FileManager.default.removeItem(at: snapshotURL)
            throw error
        }
    }

    private func decodeSnapshot(from record: CKRecord) throws -> FamilyCloudSnapshot {
        if let asset = record[Field.snapshotAsset] as? CKAsset,
           let fileURL = asset.fileURL {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile != false,
                  (values.fileSize ?? 0) <= maxSnapshotByteCount else {
                throw FamilyCloudError.snapshotTooLarge
            }
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            guard data.count <= maxSnapshotByteCount else {
                throw FamilyCloudError.snapshotTooLarge
            }
            return try JSONDecoder().decode(FamilyCloudSnapshot.self, from: data)
        }

        if let data = record[Field.snapshot] as? Data {
            guard data.count <= maxSnapshotByteCount else {
                throw FamilyCloudError.snapshotTooLarge
            }
            return try JSONDecoder().decode(FamilyCloudSnapshot.self, from: data)
        }

        throw FamilyCloudError.invalidSnapshot
    }

    private func upsertAchievementAssets(locator: StoredLocator, rootRecord: CKRecord, database: CKDatabase) async throws {
        guard let achievementStore else { return }
        let assets = achievementStore.exportAchievementAssetURLs()
        guard !assets.isEmpty else { return }

        var temporaryURLs: [URL] = []
        defer {
            temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        }

        var records: [CKRecord] = []
        for item in assets {
            let recordID = CKRecord.ID(recordName: "achievementAsset-\(item.achievementID.uuidString)", zoneID: locator.zoneID)
            let record = try await fetchOptionalRecord(recordID, from: database)
                ?? CKRecord(recordType: RecordType.achievementAsset, recordID: recordID)
            record[Field.babySpace] = CKRecord.Reference(record: rootRecord, action: .deleteSelf)
            if let stickerFilename = item.stickerFilename {
                record[Field.stickerFilename] = stickerFilename as CKRecordValue
            } else {
                record[Field.stickerFilename] = nil
                record[Field.stickerAsset] = nil
            }
            if let originalFilename = item.originalFilename {
                record[Field.originalFilename] = originalFilename as CKRecordValue
            } else {
                record[Field.originalFilename] = nil
            }
            if let stickerAssetURL = item.stickerURL {
                temporaryURLs.append(stickerAssetURL)
                record[Field.stickerAsset] = CKAsset(fileURL: stickerAssetURL)
            }
            if let originalAssetURL = item.originalURL {
                temporaryURLs.append(originalAssetURL)
                record[Field.originalAsset] = CKAsset(fileURL: originalAssetURL)
            } else if item.originalFilename == nil {
                record[Field.originalAsset] = nil
            }
            setFilename(item.sourceFilename, assetURL: item.sourceURL, filenameField: Field.sourceFilename, assetField: Field.sourceAsset, record: record, temporaryURLs: &temporaryURLs)
            setFilename(item.livePhotoStillFilename, assetURL: item.livePhotoStillURL, filenameField: Field.livePhotoStillFilename, assetField: Field.livePhotoStillAsset, record: record, temporaryURLs: &temporaryURLs)
            setFilename(item.livePhotoMovieFilename, assetURL: item.livePhotoMovieURL, filenameField: Field.livePhotoMovieFilename, assetField: Field.livePhotoMovieAsset, record: record, temporaryURLs: &temporaryURLs)
            records.append(record)
        }

        try await save(records: records, in: database)
    }

    private func fetchAchievementAssetFiles(rootRecord: CKRecord, database: CKDatabase) async throws -> [UUID: AchievementAssetFiles] {
        let reference = CKRecord.Reference(record: rootRecord, action: .none)
        let predicate = NSPredicate(format: "%K == %@", Field.babySpace, reference)
        let query = CKQuery(recordType: RecordType.achievementAsset, predicate: predicate)
        let records = try await fetchAll(query: query, in: rootRecord.recordID.zoneID, database: database)
        var files: [UUID: AchievementAssetFiles] = [:]
        for record in records {
            let prefix = "achievementAsset-"
            guard record.recordID.recordName.hasPrefix(prefix),
                  let achievementID = UUID(uuidString: String(record.recordID.recordName.dropFirst(prefix.count))) else {
                continue
            }
            let stickerFilename = (record[Field.stickerFilename] as? String).flatMap { filename in
                AchievementAssetFilenamePolicy.isValidStickerFilename(filename) ? filename : nil
            }
            let originalFilename = (record[Field.originalFilename] as? String).flatMap { filename in
                AchievementAssetFilenamePolicy.isValidOriginalFilename(filename) ? filename : nil
            }
            let sourceFilename = validOriginalFilename(record[Field.sourceFilename] as? String)
            let livePhotoStillFilename = validOriginalFilename(record[Field.livePhotoStillFilename] as? String)
            let livePhotoMovieFilename = (record[Field.livePhotoMovieFilename] as? String).flatMap { filename in
                AchievementAssetFilenamePolicy.isValidLivePhotoFilename(filename) ? filename : nil
            }
            files[achievementID] = AchievementAssetFiles(
                achievementID: achievementID,
                stickerFilename: stickerFilename,
                originalFilename: originalFilename,
                sourceFilename: sourceFilename,
                livePhotoStillFilename: livePhotoStillFilename,
                livePhotoMovieFilename: livePhotoMovieFilename,
                stickerURL: safeRemoteAssetURL((record[Field.stickerAsset] as? CKAsset)?.fileURL),
                originalURL: safeRemoteAssetURL((record[Field.originalAsset] as? CKAsset)?.fileURL),
                sourceURL: safeRemoteAssetURL((record[Field.sourceAsset] as? CKAsset)?.fileURL),
                livePhotoStillURL: safeRemoteAssetURL((record[Field.livePhotoStillAsset] as? CKAsset)?.fileURL),
                livePhotoMovieURL: safeRemoteAssetURL((record[Field.livePhotoMovieAsset] as? CKAsset)?.fileURL)
            )
        }
        return files
    }

    private func setFilename(
        _ filename: String?,
        assetURL: URL?,
        filenameField: String,
        assetField: String,
        record: CKRecord,
        temporaryURLs: inout [URL]
    ) {
        guard let filename else {
            record[filenameField] = nil
            record[assetField] = nil
            return
        }
        record[filenameField] = filename as CKRecordValue
        if let assetURL {
            temporaryURLs.append(assetURL)
            record[assetField] = CKAsset(fileURL: assetURL)
        }
    }

    private func validOriginalFilename(_ filename: String?) -> String? {
        filename.flatMap { AchievementAssetFilenamePolicy.isValidOriginalFilename($0) ? $0 : nil }
    }

    private func safeRemoteAssetURL(_ url: URL?) -> URL? {
        guard let url, url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile != false,
              let fileSize = values.fileSize,
              fileSize <= maxAchievementAssetByteCount else {
            return nil
        }
        return url
    }

    private func existingOrNewShare(for rootRecord: CKRecord) async throws -> CKShare {
        if let shareReference = rootRecord.share {
            return try await fetchShare(shareReference.recordID)
        }
        return CKShare(rootRecord: rootRecord)
    }

    private func fetchShare(_ recordID: CKRecord.ID) async throws -> CKShare {
        let record = try await fetchRecord(recordID, from: container.privateCloudDatabase)
        guard let share = record as? CKShare else { throw FamilyCloudError.shareUnavailable }
        return share
    }

    private func accountIsAvailable() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status == .available)
                }
            }
        }
    }

    private func ensureCustomZone() async throws {
        let zone = CKRecordZone(zoneName: zoneName)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.privateCloudDatabase.save(zone) { _, error in
                if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                    continuation.resume()
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func fetchRecord(_ recordID: CKRecord.ID, from database: CKDatabase) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: error ?? FamilyCloudError.recordNotFound)
                }
            }
        }
    }

    private func fetchOptionalRecord(_ recordID: CKRecord.ID, from database: CKDatabase) async throws -> CKRecord? {
        do {
            return try await fetchRecord(recordID, from: database)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func save(records: [CKRecord], in database: CKDatabase) async throws {
        guard !records.isEmpty else { return }
        for batchStart in stride(from: 0, to: records.count, by: cloudModifyBatchSize) {
            let batchEnd = min(batchStart + cloudModifyBatchSize, records.count)
            try await saveBatch(Array(records[batchStart..<batchEnd]), in: database)
        }
    }

    private func saveBatch(_ records: [CKRecord], in database: CKDatabase) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.modifyRecordsResultBlock = { result in
                continuation.resume(with: result.map { _ in () })
            }
            database.add(operation)
        }
    }

    private func fetchAll(query: CKQuery, in zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> [CKRecord] {
        var output: [CKRecord] = []
        var page = try await fetchPage(query: query, zoneID: zoneID, database: database)
        output.append(contentsOf: page.records)

        while let cursor = page.cursor {
            page = try await fetchPage(cursor: cursor, database: database)
            output.append(contentsOf: page.records)
        }

        return output
    }

    private func fetchPage(query: CKQuery, zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> QueryPage {
        let operation = CKQueryOperation(query: query)
        operation.zoneID = zoneID
        return try await runQueryOperation(operation, database: database)
    }

    private func fetchPage(cursor: CKQueryOperation.Cursor, database: CKDatabase) async throws -> QueryPage {
        try await runQueryOperation(CKQueryOperation(cursor: cursor), database: database)
    }

    private func runQueryOperation(_ operation: CKQueryOperation, database: CKDatabase) async throws -> QueryPage {
        try await withCheckedThrowingContinuation { continuation in
            var records: [CKRecord] = []
            var matchedError: Error?
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    matchedError = matchedError ?? error
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let matchedError {
                        continuation.resume(throwing: matchedError)
                    } else {
                        continuation.resume(returning: QueryPage(records: records, cursor: cursor))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    private func accept(metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.acceptSharesResultBlock = { result in
                continuation.resume(with: result.map { _ in () })
            }
            container.add(operation)
        }
    }

    private func storedLocator() -> StoredLocator? {
        guard let data = UserDefaults.standard.data(forKey: localLocatorKey) else { return nil }
        return try? JSONDecoder().decode(StoredLocator.self, from: data)
    }

    private func saveLocator(_ locator: StoredLocator) {
        guard let data = try? JSONEncoder().encode(locator) else { return }
        UserDefaults.standard.set(data, forKey: localLocatorKey)
    }

    private func storedLocalSnapshotUpdatedAt() -> Date? {
        UserDefaults.standard.object(forKey: localSnapshotUpdatedAtKey) as? Date
    }

    private func setLocalSnapshotUpdatedAt(_ date: Date) {
        UserDefaults.standard.set(date, forKey: localSnapshotUpdatedAtKey)
    }

    private func localSnapshotIsDirty() -> Bool {
        UserDefaults.standard.bool(forKey: localSnapshotDirtyKey)
    }

    private func setLocalSnapshotDirty(_ isDirty: Bool) {
        UserDefaults.standard.set(isDirty, forKey: localSnapshotDirtyKey)
    }

    private func deletedFeedingSessionIDs() -> Set<UUID> {
        deletedIDs(for: deletedFeedingSessionIDsKey)
    }

    private func deletedCareRecordIDs() -> Set<UUID> {
        deletedIDs(for: deletedCareRecordIDsKey)
    }

    private func deletedGrowthMetricRecordIDs() -> Set<UUID> {
        deletedIDs(for: deletedGrowthMetricRecordIDsKey)
    }

    private func deletedAchievementIDs() -> Set<UUID> {
        deletedIDs(for: deletedAchievementIDsKey)
    }

    private func deletedSubjectiveStateCheckInIDs() -> Set<UUID> {
        deletedIDs(for: deletedSubjectiveStateCheckInIDsKey)
    }

    private func setDeletedFeedingSessionIDs(_ ids: Set<UUID>) {
        setDeletedIDs(ids, key: deletedFeedingSessionIDsKey)
    }

    private func setDeletedCareRecordIDs(_ ids: Set<UUID>) {
        setDeletedIDs(ids, key: deletedCareRecordIDsKey)
    }

    private func setDeletedGrowthMetricRecordIDs(_ ids: Set<UUID>) {
        setDeletedIDs(ids, key: deletedGrowthMetricRecordIDsKey)
    }

    private func setDeletedAchievementIDs(_ ids: Set<UUID>) {
        setDeletedIDs(ids, key: deletedAchievementIDsKey)
    }

    private func setDeletedSubjectiveStateCheckInIDs(_ ids: Set<UUID>) {
        setDeletedIDs(ids, key: deletedSubjectiveStateCheckInIDsKey)
    }

    private func deletedIDs(for key: String) -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    private func addDeletedID(_ id: UUID, key: String) {
        var ids = deletedIDs(for: key)
        ids.insert(id)
        setDeletedIDs(ids, key: key)
    }

    private func setDeletedIDs(_ ids: Set<UUID>, key: String) {
        guard let data = try? JSONEncoder().encode(Array(ids)) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func uploadSnapshotUpdatedAt() -> Date {
        if let updatedAt = storedLocalSnapshotUpdatedAt(), updatedAt > .distantPast {
            return updatedAt
        }
        let updatedAt = Date()
        setLocalSnapshotUpdatedAt(updatedAt)
        return updatedAt
    }

    private func writeTemporarySnapshotAsset(_ data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(snapshotTemporaryDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(UUID().uuidString)-snapshot.json")
        try data.write(to: url, options: [.atomic])
        return url
    }
}

private struct QueryPage {
    var records: [CKRecord]
    var cursor: CKQueryOperation.Cursor?
}

enum FamilyCloudError: LocalizedError {
    case notConfigured
    case iCloudUnavailable
    case recordNotFound
    case shareUnavailable
    case invalidSnapshot
    case snapshotTooLarge
    case localDataChangedDuringSync

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "家庭共享还没有完成初始化"
        case .iCloudUnavailable: return "当前设备没有可用的 iCloud 账号"
        case .recordNotFound: return "没有找到宝宝共享空间"
        case .shareUnavailable: return "无法创建或读取共享邀请"
        case .invalidSnapshot: return "共享数据暂时无法读取"
        case .snapshotTooLarge: return "共享数据文件异常，已停止读取"
        case .localDataChangedDuringSync: return "本机记录已更新，正在重新同步"
        }
    }
}
