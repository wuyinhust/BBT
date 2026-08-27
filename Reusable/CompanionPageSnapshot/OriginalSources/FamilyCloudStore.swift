import CloudKit
import Foundation
import Network
import OSLog
import SwiftUI
import UIKit

enum FamilySharingMode: Equatable {
    case localOnly
    case plusRequired
    case iCloudUnavailable
    case owner
    case joined
}

enum FamilySyncFailure: Equatable {
    case network
    case serviceUnavailable
    case accountUnavailable
    case permission
    case quotaExceeded
    case dataIntegrity
    case unknown

    var title: String {
        switch self {
        case .network: return "网络暂不可用"
        case .serviceUnavailable: return "iCloud 服务暂不可用"
        case .accountUnavailable: return "iCloud 账号不可用"
        case .permission: return "iCloud 权限不足"
        case .quotaExceeded: return "iCloud 空间不足"
        case .dataIntegrity: return "同步数据暂时无法读取"
        case .unknown: return "家庭同步失败"
        }
    }
}

enum FamilySyncPhase: Equatable {
    case idle
    case checking
    case syncing
    case waitingForNetwork
    case retryScheduled(Date)
    case failed(FamilySyncFailure)
}

struct FamilySyncStatus: Equatable {
    var mode: FamilySharingMode
    var phase: FamilySyncPhase
    var hasPendingChanges: Bool
    var lastSuccessfulSyncAt: Date?

    var isShared: Bool {
        mode == .owner || mode == .joined
    }

    var shouldShowBanner: Bool {
        guard isShared, hasPendingChanges else { return false }
        switch phase {
        case .waitingForNetwork, .retryScheduled, .failed:
            return true
        case .syncing:
            return true
        case .idle, .checking:
            return false
        }
    }
}

enum FamilyCloudNetworkStatus: Equatable {
    case unknown
    case satisfied
    case unsatisfied
    case requiresConnection
}

protocol FamilyCloudNetworkMonitoring: AnyObject {
    var onStatusChange: ((FamilyCloudNetworkStatus) -> Void)? { get set }
    func start()
    func stop()
}

final class SystemFamilyCloudNetworkMonitor: FamilyCloudNetworkMonitoring {
    var onStatusChange: ((FamilyCloudNetworkStatus) -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "v.babybuddy.family-cloud-network")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let status: FamilyCloudNetworkStatus
            switch path.status {
            case .satisfied:
                status = .satisfied
            case .unsatisfied:
                status = .unsatisfied
            case .requiresConnection:
                status = .requiresConnection
            @unknown default:
                status = .unknown
            }
            self?.onStatusChange?(status)
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}

enum FamilySharingState: Equatable {
    case localOnly
    case plusRequired
    case checkingAccount
    case iCloudUnavailable
    case syncing
    case ownerShared
    case joinedShared
    case failed(String)

    var title: String {
        switch self {
        case .localOnly: return "仅本机记录"
        case .plusRequired: return "Plus 会员专属"
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
        case .plusRequired: return "开通 BBBuddy Plus 后，才能继续使用家庭共享同步。"
        case .checkingAccount: return "正在确认当前设备是否登录 iCloud。"
        case .iCloudUnavailable: return "请先在系统设置中登录 iCloud，并允许 iCloud Drive。"
        case .syncing: return "正在把宝宝资料、记录、成就和陪伴动物同步到 iCloud。"
        case .ownerShared: return "你创建了这个宝宝空间，可以继续邀请另一位家长。"
        case .joinedShared: return "你正在和另一位家长共同记录这个宝宝。"
        case .failed(let message): return message
        }
    }
}

struct FamilyCloudTombstone: Codable, Hashable {
    var id: UUID
    var deletedAt: Date
}

/// Version clocks for singleton values that do not have a record ID. Keeping
/// these clocks beside the snapshot prevents a profile edit on one device
/// from winning merely because a different record was saved later on another
/// device.
struct FamilyCloudFieldVersions: Codable, Equatable {
    var profileUpdatedAt: Date?
    var selectedCompanionUpdatedAt: Date?
    var temperamentUpdatedAt: Date?

    static func legacy(_ date: Date) -> FamilyCloudFieldVersions {
        FamilyCloudFieldVersions(
            profileUpdatedAt: date,
            selectedCompanionUpdatedAt: date,
            temperamentUpdatedAt: date
        )
    }
}

struct FamilyCloudSnapshot: Codable {
    var schemaVersion: Int?
    var fieldVersions: FamilyCloudFieldVersions?
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
    var deletedFeedingSessionTombstones: [FamilyCloudTombstone]?
    var deletedCareRecordTombstones: [FamilyCloudTombstone]?
    var deletedGrowthMetricRecordTombstones: [FamilyCloudTombstone]?
    var deletedAchievementTombstones: [FamilyCloudTombstone]?
    var deletedSubjectiveStateCheckInTombstones: [FamilyCloudTombstone]?
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
            "BBBuddy 宝宝空间"
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
    @Published private(set) var syncPhase: FamilySyncPhase = .idle
    @Published private(set) var hasPendingChanges = false
    @Published private(set) var syncGeneration = 0

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
    private let localLastSuccessfulSyncAtKey = "family_cloud_last_successful_sync_at_v1"
    private let localFieldVersionsKey = "family_cloud_local_field_versions_v1"
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
    private let maxCloudRecordCount = 20_000
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
    private var debounceTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var localFieldVersions: FamilyCloudFieldVersions?
    private let networkMonitor: FamilyCloudNetworkMonitoring
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "v.babybuddy",
        category: "FamilyCloudSync"
    )

    init(networkMonitor: FamilyCloudNetworkMonitoring = SystemFamilyCloudNetworkMonitor()) {
        self.networkMonitor = networkMonitor
        hasPendingChanges = UserDefaults.standard.bool(forKey: localSnapshotDirtyKey)
        lastSyncAt = UserDefaults.standard.object(forKey: localLastSuccessfulSyncAtKey) as? Date
        if let data = UserDefaults.standard.data(forKey: localFieldVersionsKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes {
            localFieldVersions = try? JSONDecoder().decode(FamilyCloudFieldVersions.self, from: data)
        }
        if AppVariant.isFamilySyncEnabled {
            networkMonitor.onStatusChange = { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.handleNetworkStatusChange(status)
                }
            }
            networkMonitor.start()
        }
    }

    deinit {
        networkMonitor.stop()
        debounceTask?.cancel()
        retryTask?.cancel()
        scheduledUploadTask?.cancel()
    }

    var syncStatus: FamilySyncStatus {
        FamilySyncStatus(
            mode: sharingMode,
            phase: syncPhase,
            hasPendingChanges: hasPendingChanges,
            lastSuccessfulSyncAt: lastSyncAt
        )
    }

    var isApplyingRemoteChanges: Bool {
        isApplyingRemoteSnapshot
    }

    private var sharingMode: FamilySharingMode {
        switch state {
        case .localOnly:
            return .localOnly
        case .plusRequired:
            return .plusRequired
        case .iCloudUnavailable:
            // Keep an existing shared space visibly shared even when the
            // account/container is temporarily unavailable. This lets the
            // global banner explain the iCloud problem while preserving the
            // local-only behavior for devices that never joined a space.
            guard let locator = storedLocator() else { return .iCloudUnavailable }
            return locator.isOwner ? .owner : .joined
        case .checkingAccount:
            return .iCloudUnavailable
        case .syncing, .ownerShared:
            guard let locator = storedLocator() else { return .localOnly }
            return locator.isOwner ? .owner : .joined
        case .failed:
            guard let locator = storedLocator() else { return .localOnly }
            return locator.isOwner ? .owner : .joined
        case .joinedShared:
            return .joined
        }
    }

    private func setSyncPhase(_ phase: FamilySyncPhase) {
        syncPhase = phase
        logger.debug("Sync phase changed: \(String(describing: phase), privacy: .public)")
    }

    private func handleNetworkStatusChange(_ status: FamilyCloudNetworkStatus) {
        guard AppVariant.isFamilySyncEnabled else { return }
        guard isConfigured, storedLocator() != nil, hasPendingChanges else { return }
        logger.debug("Network status changed: \(String(describing: status), privacy: .public)")
        guard status == .satisfied else {
            if case .syncing = syncPhase {
                setSyncPhase(.waitingForNetwork)
            } else if case .retryScheduled = syncPhase {
                retryTask?.cancel()
                retryTask = nil
                scheduledUploadTask = nil
                setSyncPhase(.waitingForNetwork)
            }
            return
        }
        let canWakeRetry: Bool
        switch syncPhase {
        case .waitingForNetwork, .retryScheduled:
            canWakeRetry = true
        case .idle, .checking, .syncing, .failed:
            canWakeRetry = false
        }
        guard canWakeRetry else { return }
        retryTask?.cancel()
        retryTask = nil
        Task { [weak self] in
            await self?.syncNow()
        }
    }

    func retryNow() {
        guard AppVariant.isFamilySyncEnabled else { return }
        guard isConfigured, storedLocator() != nil else { return }
        syncRetryAttempt = 0
        retryTask?.cancel()
        retryTask = nil
        Task { [weak self] in
            await self?.syncNow()
        }
    }

    private static var canUseCloudKitContainer: Bool {
        guard AppVariant.isFamilySyncEnabled else { return false }
        #if targetEnvironment(simulator) && arch(x86_64)
        return false
        #else
        return true
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
        guard AppVariant.isFamilySyncEnabled else { return }
        self.profileStore = profileStore
        self.feedingStore = feedingStore
        self.activityStore = activityStore
        self.growthMetricStore = growthMetricStore
        self.achievementStore = achievementStore
        self.companionStore = companionStore
        self.temperamentStore = temperamentStore
        self.subjectiveStateStore = subjectiveStateStore
        isConfigured = true
        hasPendingChanges = localSnapshotIsDirty()
        if hasPendingChanges, storedLocator() != nil {
            setSyncPhase(.retryScheduled(Date()))
        }
    }

    func bootstrapIfNeeded() async {
        guard AppVariant.isFamilySyncEnabled else { return }
        guard isConfigured else { return }
        guard PlusMembershipStore.shared.isPlusActive else {
            state = storedLocator() == nil ? .localOnly : .plusRequired
            setSyncPhase(.idle)
            return
        }
        guard Self.canUseCloudKitContainer else {
            state = .iCloudUnavailable
            setSyncPhase(.failed(.accountUnavailable))
            return
        }
        state = .checkingAccount
        setSyncPhase(.checking)
        do {
            guard try await accountIsAvailable() else {
                state = .iCloudUnavailable
                setSyncPhase(.failed(.accountUnavailable))
                return
            }
            if let locator = storedLocator() {
                state = locator.isOwner ? .ownerShared : .joinedShared
                await syncNow()
            } else {
                state = .localOnly
                setSyncPhase(.idle)
            }
        } catch {
            if Task.isCancelled || (error as? CKError)?.code == .operationCancelled {
                return
            }
            let failure = syncFailure(for: error)
            state = .failed(failure.title)
            setSyncPhase(.failed(failure))
        }
    }

    func makeInviteController() async throws -> UICloudSharingController {
        guard AppVariant.isFamilySyncEnabled else { throw FamilyCloudError.featureUnavailable }
        guard isConfigured else { throw FamilyCloudError.notConfigured }
        guard PlusMembershipStore.shared.isPlusActive else {
            state = .plusRequired
            setSyncPhase(.idle)
            throw FamilyCloudError.plusRequired
        }
        guard Self.canUseCloudKitContainer else { throw FamilyCloudError.iCloudUnavailable }
        guard try await accountIsAvailable() else { throw FamilyCloudError.iCloudUnavailable }
        state = .syncing
        setSyncPhase(.syncing)
        do {
            let expectedRevision = localMutationRevision
            let locator = try await ensureOwnerBabySpace()
            let snapshot = try snapshotForUpload()
            let rootRecord = try await upsertSnapshotRecord(locator: locator, snapshot: snapshot)
            try await upsertAchievementAssets(locator: locator, rootRecord: rootRecord, database: container.privateCloudDatabase)
            let share = try await existingOrNewShare(for: rootRecord)
            share[CKShare.SystemFieldKey.title] = "\(snapshot.profile.name) 的 BBBBuddy" as CKRecordValue
            try await save(records: [rootRecord, share], in: container.privateCloudDatabase)

            saveLocator(locator)
            finishSnapshotSync(
                snapshot.updatedAt,
                expectedRevision: expectedRevision,
                fieldVersions: snapshot.fieldVersions
            )
            lastSyncAt = Date()
            persistLastSuccessfulSyncAt()
            syncGeneration &+= 1
            state = .ownerShared
            setSyncPhase(.idle)
            return UICloudSharingController(share: share, container: container)
        } catch {
            if Task.isCancelled || (error as? CKError)?.code == .operationCancelled {
                if let locator = storedLocator() {
                    state = locator.isOwner ? .ownerShared : .joinedShared
                } else {
                    state = .localOnly
                }
                setSyncPhase(.idle)
                throw error
            }
            let failure = syncFailure(for: error)
            state = .failed(failure.title)
            setSyncPhase(failure == .network ? .waitingForNetwork : .failed(failure))
            throw error
        }
    }

    func syncNow() async {
        guard AppVariant.isFamilySyncEnabled else { return }
        guard isConfigured, storedLocator() != nil, Self.canUseCloudKitContainer else { return }
        guard PlusMembershipStore.shared.isPlusActive else {
            state = .plusRequired
            scheduledUploadTask?.cancel()
            setSyncPhase(.idle)
            return
        }
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
        let startedAt = Date()
        let attempt = syncRetryAttempt + 1
        state = .syncing
        setSyncPhase(.syncing)
        logger.debug("Sync attempt started: attempt=\(attempt, privacy: .public)")
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
                    let normalizedSnapshot = normalizedSnapshotForRecordTombstones(remoteSnapshot)
                    try await applyRemoteSnapshot(
                        normalizedSnapshot,
                        rootRecord: remoteRecord,
                        database: database,
                        expectedRevision: expectedRevision
                    )
                    if !snapshotPayloadEquals(normalizedSnapshot, remoteSnapshot) {
                        setLocalSnapshotDirty(true)
                        _ = try await saveSnapshot(
                            normalizedSnapshot,
                            rootRecord: remoteRecord,
                            database: database
                        )
                    }
                    finishSnapshotSync(
                        normalizedSnapshot.updatedAt,
                        expectedRevision: expectedRevision,
                        fieldVersions: normalizedSnapshot.fieldVersions
                    )
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
                    let normalizedSnapshot = normalizedSnapshotForRecordTombstones(mergedSnapshot)
                    try await applyRemoteSnapshot(
                        normalizedSnapshot,
                        rootRecord: remoteRecord,
                        database: database,
                        expectedRevision: expectedRevision
                    )
                    _ = try await saveSnapshot(normalizedSnapshot, rootRecord: remoteRecord, database: database)
                    try await upsertAchievementAssets(locator: locator, rootRecord: remoteRecord, database: database)
                    finishSnapshotSync(
                        normalizedSnapshot.updatedAt,
                        expectedRevision: expectedRevision,
                        fieldVersions: normalizedSnapshot.fieldVersions
                    )
                } else if !hasLocalChanges {
                    // The root snapshot and AchievementAsset records are saved
                    // separately. A receiver can therefore finish a sync after
                    // metadata arrives while the image asset query is still
                    // empty. Recheck missing images even when timestamps match.
                    let normalizedSnapshot = normalizedSnapshotForRecordTombstones(remoteSnapshot)
                    if !snapshotPayloadEquals(normalizedSnapshot, remoteSnapshot) {
                        setLocalSnapshotDirty(true)
                        _ = try await saveSnapshot(
                            normalizedSnapshot,
                            rootRecord: remoteRecord,
                            database: database
                        )
                        finishSnapshotSync(
                            normalizedSnapshot.updatedAt,
                            expectedRevision: expectedRevision,
                            fieldVersions: normalizedSnapshot.fieldVersions
                        )
                    }
                    try? await restoreMissingAchievementAssets(
                        rootRecord: remoteRecord,
                        database: database,
                        expectedRevision: expectedRevision
                    )
                } else {
                    // A local mutation can share the same root timestamp as a
                    // remote write (for example after restoring a legacy
                    // snapshot). Do not mark that dirty work as synchronized;
                    // merge it and upload the result using local tie-breaking.
                    let localSnapshot = try currentSnapshot(updatedAt: localUpdatedAt)
                    let mergedSnapshot = mergeSnapshots(
                        local: localSnapshot,
                        remote: remoteSnapshot,
                        preferRemoteFields: false
                    )
                    try await applyAndSaveIfNeeded(
                        mergedSnapshot,
                        remoteSnapshot: remoteSnapshot,
                        rootRecord: remoteRecord,
                        locator: locator,
                        database: database,
                        expectedRevision: expectedRevision
                    )
                }
            } else if locator.isOwner {
                let localSnapshot = try snapshotForUpload()
                let rootRecord = CKRecord(recordType: RecordType.babySpace, recordID: locator.recordID)
                _ = try await saveSnapshot(localSnapshot, rootRecord: rootRecord, database: database)
                try await upsertAchievementAssets(locator: locator, rootRecord: rootRecord, database: database)
                finishSnapshotSync(
                    localSnapshot.updatedAt,
                    expectedRevision: expectedRevision,
                    fieldVersions: localSnapshot.fieldVersions
                )
            } else {
                throw FamilyCloudError.recordNotFound
            }

            lastSyncAt = Date()
            persistLastSuccessfulSyncAt()
            syncGeneration &+= 1
            syncRetryAttempt = 0
            state = locator.isOwner ? .ownerShared : .joinedShared
            setSyncPhase(.idle)
            let durationMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
            logger.debug("Sync succeeded: attempt=\(attempt, privacy: .public), durationMs=\(durationMilliseconds, privacy: .public)")
        } catch FamilyCloudError.localDataChangedDuringSync {
            needsFollowUpSync = true
        } catch {
            if Task.isCancelled || (error as? CKError)?.code == .operationCancelled {
                return
            }
            let failure = syncFailure(for: error)
            state = .failed(failure.title)
            setSyncPhase(failure == .network ? .waitingForNetwork : .failed(failure))
            let durationMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
            logger.error("Sync failed: code=\(self.cloudErrorCode(for: error), privacy: .public), failure=\(String(describing: failure), privacy: .public), attempt=\(attempt, privacy: .public), durationMs=\(durationMilliseconds, privacy: .public)")
            scheduleRetryIfNeeded(for: error)
        }
    }

    func scheduleUpload(reason: String = "") {
        guard AppVariant.isFamilySyncEnabled else { return }
        guard isConfigured, !isApplyingRemoteSnapshot else { return }
        localMutationRevision &+= 1
        syncRetryAttempt = 0
        let mutationDate = Date()
        updateLocalFieldVersion(for: reason, at: mutationDate)
        setLocalSnapshotUpdatedAt(mutationDate)
        setLocalSnapshotDirty(true)
        hasPendingChanges = true
        scheduledUploadTask?.cancel()
        debounceTask?.cancel()
        retryTask?.cancel()
        guard PlusMembershipStore.shared.isPlusActive, storedLocator() != nil else { return }
        debounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(self.syncDebounce * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self.syncNow()
        }
        scheduledUploadTask = debounceTask
    }

    private func scheduleRetryIfNeeded(for error: Error) {
        if syncFailure(for: error) == .network {
            setSyncPhase(.waitingForNetwork)
            return
        }
        guard syncRetryAttempt < maxSyncRetryAttempts,
              let delay = retryDelay(for: error) else {
            return
        }
        syncRetryAttempt += 1
        scheduledUploadTask?.cancel()
        retryTask?.cancel()
        let jitter = Double.random(in: 0...0.25)
        let scheduledAt = Date().addingTimeInterval(delay * (1 + jitter))
        setSyncPhase(.retryScheduled(scheduledAt))
        retryTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(scheduledAt.timeIntervalSinceNow * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            await self.syncNow()
        }
        scheduledUploadTask = retryTask
    }

    func retryDelay(for error: Error) -> TimeInterval? {
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

    func syncFailure(for error: Error) -> FamilySyncFailure {
        if let familyError = error as? FamilyCloudError {
            switch familyError {
            case .iCloudUnavailable:
                return .accountUnavailable
            case .invalidSnapshot, .snapshotTooLarge, .recordNotFound:
                return .dataIntegrity
            case .shareUnavailable:
                return .serviceUnavailable
            case .featureUnavailable, .notConfigured, .plusRequired, .localDataChangedDuringSync:
                return .unknown
            }
        }
        guard let cloudError = error as? CKError else {
            return .unknown
        }
        switch cloudError.code {
        case .networkUnavailable, .networkFailure:
            return .network
        case .serviceUnavailable, .requestRateLimited, .zoneBusy, .partialFailure, .serverRecordChanged:
            return .serviceUnavailable
        case .notAuthenticated, .accountTemporarilyUnavailable:
            return .accountUnavailable
        case .permissionFailure, .missingEntitlement:
            return .permission
        case .quotaExceeded:
            return .quotaExceeded
        case .limitExceeded, .constraintViolation, .invalidArguments:
            return .dataIntegrity
        default:
            return .unknown
        }
    }

    private func cloudErrorCode(for error: Error) -> String {
        guard let cloudError = error as? CKError else { return "non-cloudkit" }
        return String(cloudError.code.rawValue)
    }

    func markFeedingSessionDeleted(_ id: UUID) {
        guard AppVariant.isFamilySyncEnabled else { return }
        addDeletedID(id, key: deletedFeedingSessionIDsKey)
        scheduleUpload(reason: "feeding-delete")
    }

    func markCareRecordDeleted(_ id: UUID) {
        guard AppVariant.isFamilySyncEnabled else { return }
        addDeletedID(id, key: deletedCareRecordIDsKey)
        scheduleUpload(reason: "care-delete")
    }

    func markGrowthMetricRecordDeleted(_ id: UUID) {
        guard AppVariant.isFamilySyncEnabled else { return }
        addDeletedID(id, key: deletedGrowthMetricRecordIDsKey)
        scheduleUpload(reason: "growth-delete")
    }

    func markAchievementDeleted(_ id: UUID) {
        guard AppVariant.isFamilySyncEnabled else { return }
        addDeletedID(id, key: deletedAchievementIDsKey)
        scheduleUpload(reason: "achievement-delete")
    }

    func markSubjectiveStateCheckInDeleted(_ id: UUID) {
        guard AppVariant.isFamilySyncEnabled else { return }
        addDeletedID(id, key: deletedSubjectiveStateCheckInIDsKey)
        scheduleUpload(reason: "subjective-state-delete")
    }

    func acceptShare(metadata: CKShare.Metadata) async {
        guard AppVariant.isFamilySyncEnabled else { return }
        await PlusMembershipStore.shared.refreshEntitlements()
        guard PlusMembershipStore.shared.isPlusActive else {
            state = .plusRequired
            setSyncPhase(.idle)
            return
        }
        guard Self.canUseCloudKitContainer else {
            state = .iCloudUnavailable
            setSyncPhase(.failed(.accountUnavailable))
            return
        }
        state = .syncing
        setSyncPhase(.syncing)
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
            if Task.isCancelled || (error as? CKError)?.code == .operationCancelled {
                return
            }
            let failure = syncFailure(for: error)
            state = .failed(failure.title)
            setSyncPhase(.failed(failure))
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
        let feedingSessions = feedingStore.exportSessions()
            .filter { !deletedFeedingSessionIDs.contains($0.id) }
        let careRecords = activityStore.exportCareRecords()
            .filter { !deletedCareRecordIDs.contains($0.id) }
        let growthMetricRecords = growthMetricStore.exportRecords()
            .filter { !deletedGrowthMetricRecordIDs.contains($0.id) }
        let achievements = achievementStore.exportAchievements()
            .filter { !deletedAchievementIDs.contains($0.id) }
        let subjectiveStateCheckIns = subjectiveStateStore.exportCheckIns()
            .filter { !deletedSubjectiveStateCheckInIDs.contains($0.id) }
        guard feedingSessions.count <= maxCloudRecordCount,
              careRecords.count <= maxCloudRecordCount,
              growthMetricRecords.count <= maxCloudRecordCount,
              achievements.count <= maxCloudRecordCount,
              subjectiveStateCheckIns.count <= maxCloudRecordCount,
              deletedFeedingSessionIDs.count <= maxCloudRecordCount,
              deletedCareRecordIDs.count <= maxCloudRecordCount,
              deletedGrowthMetricRecordIDs.count <= maxCloudRecordCount,
              deletedAchievementIDs.count <= maxCloudRecordCount,
              deletedSubjectiveStateCheckInIDs.count <= maxCloudRecordCount else {
            throw FamilyCloudError.snapshotTooLarge
        }

        return boundedSnapshot(FamilyCloudSnapshot(
            schemaVersion: 2,
            fieldVersions: resolvedFieldVersions(localFieldVersions, fallback: updatedAt),
            profile: profileStore.currentProfile,
            feedingSessions: feedingSessions,
            careRecords: careRecords,
            growthMetricRecords: growthMetricRecords,
            achievements: achievements,
            subjectiveStateCheckIns: subjectiveStateCheckIns,
            deletedFeedingSessionIDs: sortedIDs(deletedFeedingSessionIDs),
            deletedCareRecordIDs: sortedIDs(deletedCareRecordIDs),
            deletedGrowthMetricRecordIDs: sortedIDs(deletedGrowthMetricRecordIDs),
            deletedAchievementIDs: sortedIDs(deletedAchievementIDs),
            deletedSubjectiveStateCheckInIDs: sortedIDs(deletedSubjectiveStateCheckInIDs),
            deletedFeedingSessionTombstones: makeTombstones(ids: deletedFeedingSessionIDs, deletedAt: updatedAt),
            deletedCareRecordTombstones: makeTombstones(ids: deletedCareRecordIDs, deletedAt: updatedAt),
            deletedGrowthMetricRecordTombstones: makeTombstones(ids: deletedGrowthMetricRecordIDs, deletedAt: updatedAt),
            deletedAchievementTombstones: makeTombstones(ids: deletedAchievementIDs, deletedAt: updatedAt),
            deletedSubjectiveStateCheckInTombstones: makeTombstones(ids: deletedSubjectiveStateCheckInIDs, deletedAt: updatedAt),
            selectedCompanionID: companionStore.selectedID,
            temperamentResult: temperamentStore?.exportResult(),
            recruitment: CompanionRecruitmentStore.shared.exportSnapshot(),
            sceneEntitlements: SceneEntitlementStore.shared.exportEntitlements(),
            updatedAt: updatedAt
        ))
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
        persistLocalFieldVersions(resolvedFieldVersions(for: snapshot))
        let deletedFeedingSessionIDs = effectiveDeletedIDs(
            tombstones: snapshot.deletedFeedingSessionTombstones,
            legacyIDs: snapshot.deletedFeedingSessionIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.feedingSessions,
            id: { $0.id },
            updatedAt: { $0.syncUpdatedAt }
        )
        let deletedCareRecordIDs = effectiveDeletedIDs(
            tombstones: snapshot.deletedCareRecordTombstones,
            legacyIDs: snapshot.deletedCareRecordIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.careRecords,
            id: { $0.id },
            updatedAt: { $0.syncUpdatedAt }
        )
        let deletedGrowthMetricRecordIDs = effectiveDeletedIDs(
            tombstones: snapshot.deletedGrowthMetricRecordTombstones,
            legacyIDs: snapshot.deletedGrowthMetricRecordIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.growthMetricRecords ?? [],
            id: { $0.id },
            updatedAt: { $0.syncUpdatedAt }
        )
        let deletedAchievementIDs = effectiveDeletedIDs(
            tombstones: snapshot.deletedAchievementTombstones,
            legacyIDs: snapshot.deletedAchievementIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.achievements,
            id: { $0.id },
            updatedAt: { $0.syncUpdatedAt }
        )
        let deletedSubjectiveStateCheckInIDs = effectiveDeletedIDs(
            tombstones: snapshot.deletedSubjectiveStateCheckInTombstones,
            legacyIDs: snapshot.deletedSubjectiveStateCheckInIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.subjectiveStateCheckIns ?? [],
            id: { $0.id },
            updatedAt: { $0.updatedAt }
        )
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
        // Asset records can become visible shortly after the root snapshot.
        // Keep the metadata import successful, then opportunistically hydrate
        // any image that was not available in the first asset query.
        try? await restoreMissingAchievementAssets(
            rootRecord: rootRecord,
            database: database,
            expectedRevision: expectedRevision
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
        let normalizedSnapshot = normalizedSnapshotForRecordTombstones(mergedSnapshot)
        if snapshotPayloadEquals(normalizedSnapshot, remoteSnapshot) {
            try await applyRemoteSnapshot(
                remoteSnapshot,
                rootRecord: rootRecord,
                database: database,
                expectedRevision: expectedRevision
            )
            finishSnapshotSync(
                remoteSnapshot.updatedAt,
                expectedRevision: expectedRevision,
                fieldVersions: remoteSnapshot.fieldVersions
            )
            return
        }

        try await applyRemoteSnapshot(
            normalizedSnapshot,
            rootRecord: rootRecord,
            database: database,
            expectedRevision: expectedRevision
        )
        _ = try await saveSnapshot(normalizedSnapshot, rootRecord: rootRecord, database: database)
        try await upsertAchievementAssets(locator: locator, rootRecord: rootRecord, database: database)
        finishSnapshotSync(
            normalizedSnapshot.updatedAt,
            expectedRevision: expectedRevision,
            fieldVersions: normalizedSnapshot.fieldVersions
        )
    }

    private func finishSnapshotSync(
        _ updatedAt: Date,
        expectedRevision: UInt64,
        fieldVersions: FamilyCloudFieldVersions? = nil
    ) {
        guard localMutationRevision == expectedRevision else {
            needsFollowUpSync = true
            return
        }
        setLocalSnapshotUpdatedAt(updatedAt)
        if let fieldVersions {
            persistLocalFieldVersions(resolvedFieldVersions(fieldVersions, fallback: updatedAt))
        }
        setLocalSnapshotDirty(false)
    }

    private func mergeSnapshots(
        local: FamilyCloudSnapshot,
        remote: FamilyCloudSnapshot,
        preferRemoteFields: Bool
    ) -> FamilyCloudSnapshot {
        let localFieldVersions = resolvedFieldVersions(for: local)
        let remoteFieldVersions = resolvedFieldVersions(for: remote)
        let profileUsesRemote = remoteWinsField(
            local: localFieldVersions.profileUpdatedAt,
            remote: remoteFieldVersions.profileUpdatedAt,
            preferRemote: preferRemoteFields
        )
        let companionUsesRemote = remoteWinsField(
            local: localFieldVersions.selectedCompanionUpdatedAt,
            remote: remoteFieldVersions.selectedCompanionUpdatedAt,
            preferRemote: preferRemoteFields
        )
        let temperamentUsesRemote = remoteWinsField(
            local: localFieldVersions.temperamentUpdatedAt,
            remote: remoteFieldVersions.temperamentUpdatedAt,
            preferRemote: preferRemoteFields
        )
        let mergedFieldVersions = FamilyCloudFieldVersions(
            profileUpdatedAt: profileUsesRemote
                ? remoteFieldVersions.profileUpdatedAt
                : localFieldVersions.profileUpdatedAt,
            selectedCompanionUpdatedAt: companionUsesRemote
                ? remoteFieldVersions.selectedCompanionUpdatedAt
                : localFieldVersions.selectedCompanionUpdatedAt,
            temperamentUpdatedAt: temperamentUsesRemote
                ? remoteFieldVersions.temperamentUpdatedAt
                : localFieldVersions.temperamentUpdatedAt
        )
        let feedingTombstones = mergedTombstones(
            local.deletedFeedingSessionTombstones,
            remote.deletedFeedingSessionTombstones,
            legacyIDs: Set(local.deletedFeedingSessionIDs ?? []).union(remote.deletedFeedingSessionIDs ?? []),
            fallbackDate: max(local.updatedAt, remote.updatedAt)
        )
        let careTombstones = mergedTombstones(
            local.deletedCareRecordTombstones,
            remote.deletedCareRecordTombstones,
            legacyIDs: Set(local.deletedCareRecordIDs ?? []).union(remote.deletedCareRecordIDs ?? []),
            fallbackDate: max(local.updatedAt, remote.updatedAt)
        )
        let growthTombstones = mergedTombstones(
            local.deletedGrowthMetricRecordTombstones,
            remote.deletedGrowthMetricRecordTombstones,
            legacyIDs: Set(local.deletedGrowthMetricRecordIDs ?? []).union(remote.deletedGrowthMetricRecordIDs ?? []),
            fallbackDate: max(local.updatedAt, remote.updatedAt)
        )
        let achievementTombstones = mergedTombstones(
            local.deletedAchievementTombstones,
            remote.deletedAchievementTombstones,
            legacyIDs: Set(local.deletedAchievementIDs ?? []).union(remote.deletedAchievementIDs ?? []),
            fallbackDate: max(local.updatedAt, remote.updatedAt)
        )
        let subjectiveTombstones = mergedTombstones(
            local.deletedSubjectiveStateCheckInTombstones,
            remote.deletedSubjectiveStateCheckInTombstones,
            legacyIDs: Set(local.deletedSubjectiveStateCheckInIDs ?? []).union(remote.deletedSubjectiveStateCheckInIDs ?? []),
            fallbackDate: max(local.updatedAt, remote.updatedAt)
        )
        let deletedFeedingSessionIDs = Set(feedingTombstones.map(\.id))
        let deletedCareRecordIDs = Set(careTombstones.map(\.id))
        let deletedGrowthMetricRecordIDs = Set(growthTombstones.map(\.id))
        let deletedAchievementIDs = Set(achievementTombstones.map(\.id))
        let deletedSubjectiveStateCheckInIDs = Set(subjectiveTombstones.map(\.id))
        return boundedSnapshot(FamilyCloudSnapshot(
            schemaVersion: 2,
            fieldVersions: mergedFieldVersions,
            profile: profileUsesRemote ? remote.profile : local.profile,
            feedingSessions: mergedByID(
                local.feedingSessions,
                remote.feedingSessions,
                deletedAt: Dictionary(uniqueKeysWithValues: feedingTombstones.map { ($0.id, $0.deletedAt) }),
                preferRemote: preferRemoteFields,
                updatedAt: { $0.syncUpdatedAt },
                sortedBy: { $0.createdAt > $1.createdAt }
            ),
            careRecords: mergedByID(
                local.careRecords,
                remote.careRecords,
                deletedAt: Dictionary(uniqueKeysWithValues: careTombstones.map { ($0.id, $0.deletedAt) }),
                preferRemote: preferRemoteFields,
                updatedAt: { $0.syncUpdatedAt },
                sortedBy: { $0.recordedAt > $1.recordedAt }
            ),
            growthMetricRecords: mergedByID(
                local.growthMetricRecords ?? [],
                remote.growthMetricRecords ?? [],
                deletedAt: Dictionary(uniqueKeysWithValues: growthTombstones.map { ($0.id, $0.deletedAt) }),
                preferRemote: preferRemoteFields,
                updatedAt: { $0.syncUpdatedAt },
                sortedBy: { $0.recordedAt > $1.recordedAt }
            ),
            achievements: mergedByID(
                local.achievements,
                remote.achievements,
                deletedAt: Dictionary(uniqueKeysWithValues: achievementTombstones.map { ($0.id, $0.deletedAt) }),
                preferRemote: preferRemoteFields,
                updatedAt: { $0.syncUpdatedAt },
                sortedBy: { $0.completedAt > $1.completedAt }
            ),
            subjectiveStateCheckIns: mergedSubjectiveStateCheckIns(
                local.subjectiveStateCheckIns ?? [],
                remote.subjectiveStateCheckIns ?? [],
                deletedAt: Dictionary(uniqueKeysWithValues: subjectiveTombstones.map { ($0.id, $0.deletedAt) })
            ),
            deletedFeedingSessionIDs: sortedIDs(deletedFeedingSessionIDs),
            deletedCareRecordIDs: sortedIDs(deletedCareRecordIDs),
            deletedGrowthMetricRecordIDs: sortedIDs(deletedGrowthMetricRecordIDs),
            deletedAchievementIDs: sortedIDs(deletedAchievementIDs),
            deletedSubjectiveStateCheckInIDs: sortedIDs(deletedSubjectiveStateCheckInIDs),
            deletedFeedingSessionTombstones: feedingTombstones,
            deletedCareRecordTombstones: careTombstones,
            deletedGrowthMetricRecordTombstones: growthTombstones,
            deletedAchievementTombstones: achievementTombstones,
            deletedSubjectiveStateCheckInTombstones: subjectiveTombstones,
            selectedCompanionID: companionUsesRemote
                ? remote.selectedCompanionID
                : local.selectedCompanionID,
            temperamentResult: temperamentUsesRemote
                ? remote.temperamentResult
                : local.temperamentResult,
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
        ))
    }

    private func mergeRecruitmentSnapshots(
        _ local: CompanionRecruitmentSnapshot?,
        _ remote: CompanionRecruitmentSnapshot?,
        preferRemote: Bool
    ) -> CompanionRecruitmentSnapshot? {
        guard let local else { return remote }
        guard let remote else { return local }
        return CompanionRecruitmentLedgerMerger.merge(
            local: local,
            remote: remote,
            preferRemoteFields: preferRemote
        )
    }

    private func mergedEntitlements(
        _ local: [SceneEntitlement],
        _ remote: [SceneEntitlement]
    ) -> [SceneEntitlement] {
        var byID: [String: SceneEntitlement] = [:]
        for entitlement in local where byID[entitlement.id] == nil {
            byID[entitlement.id] = entitlement
        }
        for entitlement in remote {
            byID[entitlement.id] = byID[entitlement.id] ?? entitlement
        }
        return Array(byID.values.sorted { $0.awardedAt < $1.awardedAt }.prefix(256))
    }

    private func mergedByID<Item: Identifiable>(
        _ localItems: [Item],
        _ remoteItems: [Item],
        deletedAt: [Item.ID: Date],
        preferRemote: Bool,
        updatedAt: (Item) -> Date,
        sortedBy areInIncreasingOrder: (Item, Item) -> Bool
    ) -> [Item] where Item.ID: Hashable {
        var merged: [Item.ID: Item] = [:]
        for item in localItems where deletedAt[item.id].map({ updatedAt(item) > $0 }) ?? true {
            merged[item.id] = item
        }
        for item in remoteItems where deletedAt[item.id].map({ updatedAt(item) > $0 }) ?? true {
            guard let current = merged[item.id] else {
                merged[item.id] = item
                continue
            }
            if updatedAt(item) > updatedAt(current)
                || (updatedAt(item) == updatedAt(current) && preferRemote) {
                merged[item.id] = item
            }
        }
        return Array(merged.values.sorted(by: areInIncreasingOrder).prefix(maxCloudRecordCount))
    }

    private func effectiveDeletedIDs<Item>(
        tombstones: [FamilyCloudTombstone]?,
        legacyIDs: [UUID]?,
        fallbackDate: Date,
        records: [Item],
        id: (Item) -> UUID,
        updatedAt: (Item) -> Date
    ) -> Set<UUID> {
        var deletionDates = Dictionary(
            uniqueKeysWithValues: (tombstones ?? []).map { ($0.id, $0.deletedAt) }
        )
        for id in legacyIDs ?? [] where deletionDates[id] == nil {
            deletionDates[id] = fallbackDate
        }
        for record in records {
            let recordID = id(record)
            guard let deletedAt = deletionDates[recordID],
                  updatedAt(record) > deletedAt else {
                continue
            }
            deletionDates[recordID] = nil
        }
        return Set(deletionDates.keys)
    }

    private func mergedSubjectiveStateCheckIns(
        _ localItems: [SubjectiveStateCheckIn],
        _ remoteItems: [SubjectiveStateCheckIn],
        deletedAt: [UUID: Date]
    ) -> [SubjectiveStateCheckIn] {
        var merged: [UUID: SubjectiveStateCheckIn] = [:]
        for item in localItems where deletedAt[item.id].map({ item.updatedAt > $0 }) ?? true {
            merged[item.id] = item
        }
        for item in remoteItems where deletedAt[item.id].map({ item.updatedAt > $0 }) ?? true {
            guard let current = merged[item.id] else {
                merged[item.id] = item
                continue
            }
            if item.updatedAt > current.updatedAt {
                merged[item.id] = item
            }
        }
        return Array(merged.values.sorted { $0.recordedAt > $1.recordedAt }.prefix(maxCloudRecordCount))
    }

    private func sortedIDs(_ ids: Set<UUID>) -> [UUID] {
        ids.sorted { $0.uuidString < $1.uuidString }
    }

    private func makeTombstones(ids: Set<UUID>, deletedAt: Date) -> [FamilyCloudTombstone] {
        ids
            .map { FamilyCloudTombstone(id: $0, deletedAt: deletedAt) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func mergedTombstones(
        _ local: [FamilyCloudTombstone]?,
        _ remote: [FamilyCloudTombstone]?,
        legacyIDs: Set<UUID>,
        fallbackDate: Date
    ) -> [FamilyCloudTombstone] {
        var byID: [UUID: FamilyCloudTombstone] = [:]
        for tombstone in local ?? [] {
            byID[tombstone.id] = tombstone
        }
        for tombstone in remote ?? [] {
            if let current = byID[tombstone.id] {
                byID[tombstone.id] = max(current.deletedAt, tombstone.deletedAt) == tombstone.deletedAt
                    ? tombstone
                    : current
            } else {
                byID[tombstone.id] = tombstone
            }
        }
        for id in legacyIDs where byID[id] == nil {
            byID[id] = FamilyCloudTombstone(id: id, deletedAt: fallbackDate)
        }
        return byID.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func resolvedFieldVersions(for snapshot: FamilyCloudSnapshot) -> FamilyCloudFieldVersions {
        resolvedFieldVersions(snapshot.fieldVersions, fallback: snapshot.updatedAt)
    }

    private func resolvedFieldVersions(
        _ versions: FamilyCloudFieldVersions?,
        fallback: Date
    ) -> FamilyCloudFieldVersions {
        let source = versions ?? .legacy(fallback)
        return FamilyCloudFieldVersions(
            profileUpdatedAt: source.profileUpdatedAt ?? fallback,
            selectedCompanionUpdatedAt: source.selectedCompanionUpdatedAt ?? fallback,
            temperamentUpdatedAt: source.temperamentUpdatedAt ?? fallback
        )
    }

    private func remoteWinsField(local: Date?, remote: Date?, preferRemote: Bool) -> Bool {
        let localDate = local ?? .distantPast
        let remoteDate = remote ?? .distantPast
        return remoteDate > localDate || (remoteDate == localDate && preferRemote)
    }

    private func normalizedSnapshotForRecordTombstones(
        _ snapshot: FamilyCloudSnapshot
    ) -> FamilyCloudSnapshot {
        var normalized = snapshot
        normalized.schemaVersion = 2
        normalized.fieldVersions = resolvedFieldVersions(for: snapshot)
        normalized.deletedFeedingSessionTombstones = normalizedTombstones(
            snapshot.deletedFeedingSessionTombstones,
            legacyIDs: snapshot.deletedFeedingSessionIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.feedingSessions,
            id: { $0.id },
            updatedAt: { $0.syncUpdatedAt }
        )
        normalized.deletedCareRecordTombstones = normalizedTombstones(
            snapshot.deletedCareRecordTombstones,
            legacyIDs: snapshot.deletedCareRecordIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.careRecords,
            id: { $0.id },
            updatedAt: { $0.syncUpdatedAt }
        )
        normalized.deletedGrowthMetricRecordTombstones = normalizedTombstones(
            snapshot.deletedGrowthMetricRecordTombstones,
            legacyIDs: snapshot.deletedGrowthMetricRecordIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.growthMetricRecords ?? [],
            id: { $0.id },
            updatedAt: { $0.syncUpdatedAt }
        )
        normalized.deletedAchievementTombstones = normalizedTombstones(
            snapshot.deletedAchievementTombstones,
            legacyIDs: snapshot.deletedAchievementIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.achievements,
            id: { $0.id },
            updatedAt: { $0.syncUpdatedAt }
        )
        normalized.deletedSubjectiveStateCheckInTombstones = normalizedTombstones(
            snapshot.deletedSubjectiveStateCheckInTombstones,
            legacyIDs: snapshot.deletedSubjectiveStateCheckInIDs,
            fallbackDate: snapshot.updatedAt,
            records: snapshot.subjectiveStateCheckIns ?? [],
            id: { $0.id },
            updatedAt: { $0.updatedAt }
        )
        normalized.deletedFeedingSessionIDs = sortedIDs(Set(normalized.deletedFeedingSessionTombstones?.map(\.id) ?? []))
        normalized.deletedCareRecordIDs = sortedIDs(Set(normalized.deletedCareRecordTombstones?.map(\.id) ?? []))
        normalized.deletedGrowthMetricRecordIDs = sortedIDs(Set(normalized.deletedGrowthMetricRecordTombstones?.map(\.id) ?? []))
        normalized.deletedAchievementIDs = sortedIDs(Set(normalized.deletedAchievementTombstones?.map(\.id) ?? []))
        normalized.deletedSubjectiveStateCheckInIDs = sortedIDs(Set(normalized.deletedSubjectiveStateCheckInTombstones?.map(\.id) ?? []))
        return normalized
    }

    private func normalizedTombstones<Item>(
        _ tombstones: [FamilyCloudTombstone]?,
        legacyIDs: [UUID]?,
        fallbackDate: Date,
        records: [Item],
        id: (Item) -> UUID,
        updatedAt: (Item) -> Date
    ) -> [FamilyCloudTombstone] {
        var byID = Dictionary(uniqueKeysWithValues: (tombstones ?? []).map { ($0.id, $0) })
        for id in legacyIDs ?? [] where byID[id] == nil {
            byID[id] = FamilyCloudTombstone(id: id, deletedAt: fallbackDate)
        }
        for record in records {
            let recordID = id(record)
            guard let tombstone = byID[recordID], updatedAt(record) > tombstone.deletedAt else {
                continue
            }
            byID[recordID] = nil
        }
        return byID.values.sorted { $0.id.uuidString < $1.id.uuidString }
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

    private func boundedSnapshot(_ snapshot: FamilyCloudSnapshot) -> FamilyCloudSnapshot {
        var bounded = snapshot
        bounded.feedingSessions = Array(snapshot.feedingSessions.prefix(maxCloudRecordCount))
        bounded.careRecords = Array(snapshot.careRecords.prefix(maxCloudRecordCount))
        bounded.growthMetricRecords = snapshot.growthMetricRecords.map {
            Array($0.prefix(maxCloudRecordCount))
        }
        bounded.achievements = Array(snapshot.achievements.prefix(maxCloudRecordCount))
        bounded.subjectiveStateCheckIns = snapshot.subjectiveStateCheckIns.map {
            Array($0.prefix(maxCloudRecordCount))
        }
        bounded.deletedFeedingSessionIDs = Array((snapshot.deletedFeedingSessionIDs ?? []).prefix(maxCloudRecordCount))
        bounded.deletedCareRecordIDs = Array((snapshot.deletedCareRecordIDs ?? []).prefix(maxCloudRecordCount))
        bounded.deletedGrowthMetricRecordIDs = Array((snapshot.deletedGrowthMetricRecordIDs ?? []).prefix(maxCloudRecordCount))
        bounded.deletedAchievementIDs = Array((snapshot.deletedAchievementIDs ?? []).prefix(maxCloudRecordCount))
        bounded.deletedSubjectiveStateCheckInIDs = Array((snapshot.deletedSubjectiveStateCheckInIDs ?? []).prefix(maxCloudRecordCount))
        bounded.deletedFeedingSessionTombstones = snapshot.deletedFeedingSessionTombstones.map { Array($0.prefix(maxCloudRecordCount)) }
        bounded.deletedCareRecordTombstones = snapshot.deletedCareRecordTombstones.map { Array($0.prefix(maxCloudRecordCount)) }
        bounded.deletedGrowthMetricRecordTombstones = snapshot.deletedGrowthMetricRecordTombstones.map { Array($0.prefix(maxCloudRecordCount)) }
        bounded.deletedAchievementTombstones = snapshot.deletedAchievementTombstones.map { Array($0.prefix(maxCloudRecordCount)) }
        bounded.deletedSubjectiveStateCheckInTombstones = snapshot.deletedSubjectiveStateCheckInTombstones.map { Array($0.prefix(maxCloudRecordCount)) }
        bounded.sceneEntitlements = snapshot.sceneEntitlements.map { Array($0.prefix(256)) }
        bounded.recruitment = snapshot.recruitment.map(CompanionRecruitmentLedgerMerger.sanitizedSnapshot)
        return bounded
    }

    private func upsertSnapshotRecord(locator: StoredLocator, snapshot: FamilyCloudSnapshot) async throws -> CKRecord {
        let database = container.privateCloudDatabase
        let record = (try? await fetchRecord(locator.recordID, from: database))
            ?? CKRecord(recordType: RecordType.babySpace, recordID: locator.recordID)
        return try await saveSnapshot(snapshot, rootRecord: record, database: database)
    }

    private func saveSnapshot(_ snapshot: FamilyCloudSnapshot, rootRecord: CKRecord, database: CKDatabase) async throws -> CKRecord {
        let data = try JSONEncoder().encode(snapshot)
        guard data.count <= maxSnapshotByteCount else {
            throw FamilyCloudError.snapshotTooLarge
        }
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
            return boundedSnapshot(try JSONDecoder().decode(FamilyCloudSnapshot.self, from: data))
        }

        if let data = record[Field.snapshot] as? Data {
            guard data.count <= maxSnapshotByteCount else {
                throw FamilyCloudError.snapshotTooLarge
            }
            return boundedSnapshot(try JSONDecoder().decode(FamilyCloudSnapshot.self, from: data))
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

    private func restoreMissingAchievementAssets(
        rootRecord: CKRecord,
        database: CKDatabase,
        expectedRevision: UInt64
    ) async throws {
        guard let achievementStore,
              !achievementStore.missingDisplayImageAssetAchievementIDs().isEmpty else {
            return
        }

        let retryDelays: [Duration] = [
            .milliseconds(250),
            .milliseconds(750),
            .seconds(1.5)
        ]
        for delay in retryDelays {
            guard !Task.isCancelled else { return }
            try await Task.sleep(for: delay)
            let assets = try await fetchAchievementAssetFiles(rootRecord: rootRecord, database: database)
            guard localMutationRevision == expectedRevision else {
                throw FamilyCloudError.localDataChangedDuringSync
            }
            _ = achievementStore.restoreAchievementAssets(assets)
            if achievementStore.missingDisplayImageAssetAchievementIDs().isEmpty {
                return
            }
        }
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
        guard page.records.count <= maxCloudRecordCount else {
            throw FamilyCloudError.snapshotTooLarge
        }
        output.append(contentsOf: page.records)

        while let cursor = page.cursor {
            page = try await fetchPage(cursor: cursor, database: database)
            guard page.records.count <= maxCloudRecordCount,
                  output.count <= maxCloudRecordCount - page.records.count else {
                throw FamilyCloudError.snapshotTooLarge
            }
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
            let stateLock = NSLock()
            var records: [CKRecord] = []
            var matchedError: Error?
            var didFinish = false

            func finish(_ result: Result<QueryPage, Error>) {
                stateLock.lock()
                guard !didFinish else {
                    stateLock.unlock()
                    return
                }
                didFinish = true
                stateLock.unlock()
                continuation.resume(with: result)
            }

            operation.recordMatchedBlock = { _, result in
                stateLock.lock()
                defer { stateLock.unlock() }
                guard !didFinish else { return }
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
                    stateLock.lock()
                    let error = matchedError
                    let pageRecords = records
                    stateLock.unlock()
                    if let error {
                        finish(.failure(error))
                    } else {
                        finish(.success(QueryPage(records: pageRecords, cursor: cursor)))
                    }
                case .failure(let error):
                    finish(.failure(error))
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
        guard let data = UserDefaults.standard.data(forKey: localLocatorKey),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes else { return nil }
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

    private func updateLocalFieldVersion(for reason: String, at date: Date) {
        let fallback = storedLocalSnapshotUpdatedAt() ?? date
        var versions = resolvedFieldVersions(localFieldVersions, fallback: fallback)
        switch reason {
        case "profile":
            versions.profileUpdatedAt = date
        case "companion":
            versions.selectedCompanionUpdatedAt = date
        case "temperament":
            versions.temperamentUpdatedAt = date
        default:
            break
        }
        persistLocalFieldVersions(versions)
    }

    private func persistLocalFieldVersions(_ versions: FamilyCloudFieldVersions) {
        localFieldVersions = versions
        guard let data = try? JSONEncoder().encode(versions),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes else {
            return
        }
        UserDefaults.standard.set(data, forKey: localFieldVersionsKey)
    }

    private func localSnapshotIsDirty() -> Bool {
        UserDefaults.standard.bool(forKey: localSnapshotDirtyKey)
    }

    private func setLocalSnapshotDirty(_ isDirty: Bool) {
        UserDefaults.standard.set(isDirty, forKey: localSnapshotDirtyKey)
        hasPendingChanges = isDirty
    }

    private func persistLastSuccessfulSyncAt() {
        guard let lastSyncAt else { return }
        UserDefaults.standard.set(lastSyncAt, forKey: localLastSuccessfulSyncAtKey)
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
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(ids.prefix(maxCloudRecordCount))
    }

    private func addDeletedID(_ id: UUID, key: String) {
        var ids = deletedIDs(for: key)
        ids.insert(id)
        setDeletedIDs(ids, key: key)
    }

    private func setDeletedIDs(_ ids: Set<UUID>, key: String) {
        guard let data = try? JSONEncoder().encode(Array(ids.prefix(maxCloudRecordCount))),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes else { return }
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
    case featureUnavailable
    case notConfigured
    case plusRequired
    case iCloudUnavailable
    case recordNotFound
    case shareUnavailable
    case invalidSnapshot
    case snapshotTooLarge
    case localDataChangedDuringSync

    var errorDescription: String? {
        switch self {
        case .featureUnavailable: return "家庭共享暂未开放"
        case .notConfigured: return "家庭共享还没有完成初始化"
        case .plusRequired: return "开通 BBBuddy Plus 后才能使用家庭共享"
        case .iCloudUnavailable: return "当前设备没有可用的 iCloud 账号"
        case .recordNotFound: return "没有找到宝宝共享空间"
        case .shareUnavailable: return "无法创建或读取共享邀请"
        case .invalidSnapshot: return "共享数据暂时无法读取"
        case .snapshotTooLarge: return "共享数据文件异常，已停止读取"
        case .localDataChangedDuringSync: return "本机记录已更新，正在重新同步"
        }
    }
}
