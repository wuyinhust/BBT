import AVFoundation
import SwiftUI
import Foundation
import ImageIO
import Observation
import OSLog
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

enum BBBDataSafetyLimits {
    static let maxJSONDataBytes = 16 * 1_024 * 1_024
    static let maxDraftDataBytes = 4 * 1_024 * 1_024
    static let maxImageDataBytes = 8 * 1_024 * 1_024
    // Data is base64-encoded inside the profile JSON. Keep the total avatar
    // media budget below the persisted JSON limit, including history.
    static let maxProfileMediaBytes = 10 * 1_024 * 1_024
    static let maxUserTextCharacters = 4_000
    static let maxIdentifierCharacters = 512
    static let maxImagePixelDimension = 2_048
    static let maxFeedingEntries = 64
    static let maxFeedingSessions = 10_000
    static let maxCareRecords = 20_000
    static let maxGrowthMetricRecords = 20_000
    static let maxAchievementRecords = 2_000
    static let maxRecruitmentTransactions = 10_000
}

enum BBBImageDataImporter {
    static func downsampledJPEG(
        data: Data,
        compressionQuality: CGFloat
    ) -> Data? {
        guard data.count <= BBBDataSafetyLimits.maxImageDataBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: BBBDataSafetyLimits.maxImagePixelDimension
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image).jpegData(compressionQuality: compressionQuality)
    }
}

// MARK: - Design

enum DesignToken {
    // Base roles. Every UI surface should resolve through these named colors.
    static let canvas = Color("BB_Canvas")
    static let surface = Color("BB_Surface")
    static let surfaceRaised = Color("BB_SurfaceRaised")
    static let surfaceSoft = Color("BB_SurfaceSoft")
    static let borderSubtle = Color("BB_Border")
    static let textStrong = Color("BB_TextStrong")
    static let textMuted = Color("BB_TextMuted")
    static let textFaint = Color("BB_TextFaint")
    static let onPrimary = Color("BB_OnPrimary")
    static let glassFill = Color("BB_GlassFill")
    static let glassStroke = Color("BB_GlassStroke")
    static let shadowColor = Color("BB_Shadow")
    static let scrim = Color("BB_Scrim")

    static let primary = Color("BB_PrimaryAction")
    static let primarySoft = Color("BB_BrandSoft")
    static let accentBlue = Color("BB_AccentBlue")
    static let grayNeutral = Color("BB_GrayNeutral")
    static let background = canvas
    static let textTitle = textStrong
    static let textBody = textMuted
    static let cardBackground = surface
    static let success = Color("BB_Success")
    static let successSoft = Color("BB_SuccessSoft")
    static let successText = Color("BB_SuccessText")
    static let warning = Color("BB_Warning")
    static let warningSoft = Color("BB_WarningSoft")
    static let warningText = Color("BB_WarningText")
    static let error = Color("BB_Error")
    static let errorSoft = Color("BB_ErrorSoft")
    static let errorText = Color("BB_ErrorText")
    static let reward = Color("BB_Reward")
    static let rewardSoft = Color("BB_RewardSoft")
    static let rewardText = Color("BB_RewardText")
    static let errorRed = error

    static let bg = background
    static let card = cardBackground
    static let textPrimary = textTitle
    static let textSecondary = textBody
    static let line = borderSubtle
    static let iconSoftBG = Color("BB_IconSoft")

    // E/A/S/Y flower colors: Iris, Camellia, Delphinium, Viburnum.
    static let easyEat = Color("BB_EasyEat")
    static let easyEatSoft = Color("BB_EasyEatSoft")
    static let easyEatText = Color("BB_EasyEatText")
    static let easyActivity = Color("BB_EasyActivity")
    static let easyActivitySoft = Color("BB_EasyActivitySoft")
    static let easyActivityText = Color("BB_EasyActivityText")
    static let easySleep = Color("BB_EasySleep")
    static let easySleepSoft = Color("BB_EasySleepSoft")
    static let easySleepText = Color("BB_EasySleepText")
    static let easyYearning = Color("BB_EasyYearning")
    static let easyYearningSoft = Color("BB_EasyYearningSoft")
    static let easyYearningText = Color("BB_EasyYearningText")

    static let feedingBottle = easyEat
    static let feedingBottleSoft = easyEatSoft
    static let feedingBreast = Color("BB_FeedingBreast")
    static let feedingBreastSoft = Color("BB_FeedingBreastSoft")
    static let feedingSolid = Color("BB_FeedingSolid")
    static let feedingSolidSoft = Color("BB_FeedingSolidSoft")

    static let activityDiaper = Color("BB_Diaper")
    static let activityDiaperSoft = Color("BB_DiaperSoft")
    static let activityDiaperText = Color("BB_DiaperText")
    static let activityBath = Color("BB_Bath")
    static let activityBathSoft = Color("BB_BathSoft")
    static let activityTummyTime = easyActivity
    static let activityComfort = easyActivity

    static let primaryGradient = LinearGradient(
        colors: [primary, primarySoft],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let primaryGradientVertical = LinearGradient(
        colors: [primary, primarySoft],
        startPoint: .top,
        endPoint: .bottom
    )
    // Shared by the active EASY-cycle label and its related home controls.
    static let easyCycleGradient = LinearGradient(
        colors: [primary, feedingBreast],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 10
    static let standardPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let elementSpacing: CGFloat = 12

    static let cardRadius: CGFloat = cardCornerRadius
    static let pillRadius: CGFloat = buttonCornerRadius
    static let tabRadius: CGFloat = 34

    // App-wide layout system. Feature screens may keep their own accent art,
    // but spacing, surfaces and interaction sizes should come from these roles.
    static let screenHorizontalPadding: CGFloat = 20
    static let compactHorizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 18
    static let contentSpacing: CGFloat = 12
    static let largeCardRadius: CGFloat = 24
    static let mediumCardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 14
    static let minimumTapSize: CGFloat = 44
    static let settingsRowMinHeight: CGFloat = 64
    static let iconContainerSize: CGFloat = 36
    static let softShadow = shadowColor.opacity(0.10)
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "app_appearance_mode_v1"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct AppGlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat
    let fillOpacity: Double
    let strokeOpacity: Double
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content.background {
            shape
                .fill(
                    reduceTransparency
                        ? AnyShapeStyle(DesignToken.surfaceRaised)
                        : AnyShapeStyle(.ultraThinMaterial)
                )
                .overlay(shape.fill(DesignToken.glassFill.opacity(reduceTransparency ? 1 : fillOpacity)))
                .overlay(shape.stroke(DesignToken.glassStroke.opacity(strokeOpacity), lineWidth: 1))
                .shadow(color: DesignToken.shadowColor.opacity(shadowOpacity), radius: 18, y: 8)
        }
    }
}

extension View {
    func appGlassSurface(
        cornerRadius: CGFloat,
        fillOpacity: Double = 0.72,
        strokeOpacity: Double = 0.72,
        shadowOpacity: Double = 0.10
    ) -> some View {
        modifier(AppGlassSurfaceModifier(
            cornerRadius: cornerRadius,
            fillOpacity: fillOpacity,
            strokeOpacity: strokeOpacity,
            shadowOpacity: shadowOpacity
        ))
    }
}

// MARK: - App Feedback

enum AppHapticPreference {
    static let storageKey = "haptic_feedback_enabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true
    }
}

enum AppHapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat? = nil) {
        guard AppHapticPreference.isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        if let intensity {
            generator.impactOccurred(intensity: intensity)
        } else {
            generator.impactOccurred()
        }
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard AppHapticPreference.isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

enum AppToastStyle: String, Equatable {
    case success
    case info
    case warning
    case reward

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .reward: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .success: return DesignToken.success
        case .info: return DesignToken.accentBlue
        case .warning: return DesignToken.warning
        case .reward: return DesignToken.reward
        }
    }
}

struct AppToastMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let style: AppToastStyle
    let deduplicationKey: String
    let duration: Duration

    init(
        id: UUID = UUID(),
        text: String,
        style: AppToastStyle = .success,
        deduplicationKey: String? = nil,
        duration: Duration = .seconds(4.5)
    ) {
        self.id = id
        self.text = text
        self.style = style
        self.deduplicationKey = deduplicationKey ?? "\(style.rawValue):\(text)"
        self.duration = duration
    }
}

enum AppCelebrationKind: Equatable {
    case reward
    case milestone
}

struct AppCelebration: Identifiable, Equatable {
    let id: UUID
    let kind: AppCelebrationKind
    let title: String
    let subtitle: String
    let rewardAmount: Int
    let systemImage: String
    let deduplicationKey: String

    init(
        id: UUID = UUID(),
        kind: AppCelebrationKind,
        title: String,
        subtitle: String,
        rewardAmount: Int = 0,
        systemImage: String,
        deduplicationKey: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.rewardAmount = max(rewardAmount, 0)
        self.systemImage = systemImage
        self.deduplicationKey = deduplicationKey
    }
}

@MainActor
final class AppFeedbackCenter: ObservableObject {
    static let shared = AppFeedbackCenter()

    @Published private(set) var toast: AppToastMessage?
    @Published private(set) var celebration: AppCelebration?
    @Published private(set) var activeEmbeddedCelebrationHostID: UUID?

    private var toastQueue: [AppToastMessage] = []
    private var celebrationQueue: [AppCelebration] = []
    private var embeddedCelebrationHostIDs: [UUID] = []
    private var toastDismissTask: Task<Void, Never>?
    private var celebrationAdvanceTask: Task<Void, Never>?
    private var celebrationDeferralReasons: Set<String> = []
    private var isCelebrationTransitioning = false
    private var isSceneActive = true
    private let celebrationAdvanceDelay: Duration
    private let celebrationResumeDelay: Duration
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "v.babybuddy",
        category: "AppFeedback"
    )

    init(
        celebrationAdvanceDelay: Duration = .milliseconds(280),
        celebrationResumeDelay: Duration = .milliseconds(450)
    ) {
        self.celebrationAdvanceDelay = celebrationAdvanceDelay
        self.celebrationResumeDelay = celebrationResumeDelay
    }

    var embeddedCelebrationHostCount: Int {
        embeddedCelebrationHostIDs.count
    }

    var pendingCelebrationCount: Int {
        celebrationQueue.count
    }

    func presentToast(_ message: AppToastMessage) {
        guard toast?.deduplicationKey != message.deduplicationKey,
              !toastQueue.contains(where: { $0.deduplicationKey == message.deduplicationKey }) else {
            return
        }
        guard toast == nil else {
            toastQueue.append(message)
            return
        }
        showToast(message)
    }

    func presentReward(
        amount: Int,
        title: String,
        subtitle: String = "奖励已经放进你的 BB Bucks 钱包".localized,
        deduplicationKey: String
    ) {
        guard amount > 0 else { return }
        presentCelebration(AppCelebration(
            kind: .reward,
            title: title,
            subtitle: subtitle,
            rewardAmount: amount,
            systemImage: "b.circle.fill",
            deduplicationKey: deduplicationKey
        ))
    }

    func presentMilestone(
        title: String,
        subtitle: String,
        rewardAmount: Int = 0,
        systemImage: String = "star.fill",
        deduplicationKey: String
    ) {
        presentCelebration(AppCelebration(
            kind: .milestone,
            title: title,
            subtitle: subtitle,
            rewardAmount: rewardAmount,
            systemImage: systemImage,
            deduplicationKey: deduplicationKey
        ))
    }

    func dismissCelebration() {
        guard celebration != nil else {
            logger.debug("Ignored duplicate celebration dismissal")
            return
        }

        celebration = nil
        logger.info("Dismissed celebration; queued=\(self.celebrationQueue.count)")
        scheduleNextCelebration(after: celebrationAdvanceDelay, reason: "dismiss")
    }

    func registerEmbeddedCelebrationHost(_ hostID: UUID) {
        guard !embeddedCelebrationHostIDs.contains(hostID) else {
            logger.debug("Ignored duplicate embedded host registration")
            return
        }

        embeddedCelebrationHostIDs.append(hostID)
        activeEmbeddedCelebrationHostID = hostID
        logger.info("Registered embedded host; count=\(self.embeddedCelebrationHostIDs.count)")
    }

    func unregisterEmbeddedCelebrationHost(_ hostID: UUID) {
        let previousCount = embeddedCelebrationHostIDs.count
        embeddedCelebrationHostIDs.removeAll { $0 == hostID }
        guard embeddedCelebrationHostIDs.count != previousCount else {
            logger.debug("Ignored unknown embedded host unregistration")
            return
        }

        activeEmbeddedCelebrationHostID = embeddedCelebrationHostIDs.last
        logger.info("Unregistered embedded host; count=\(self.embeddedCelebrationHostIDs.count)")
    }

    func isActiveCelebrationHost(_ hostID: UUID, isEmbedded: Bool) -> Bool {
        if isEmbedded {
            return activeEmbeddedCelebrationHostID == hostID
        }
        return activeEmbeddedCelebrationHostID == nil
    }

    func setSceneActive(_ isActive: Bool) {
        guard isSceneActive != isActive else { return }
        isSceneActive = isActive
        logger.info("Scene active=\(isActive); queued=\(self.celebrationQueue.count)")

        celebrationAdvanceTask?.cancel()
        celebrationAdvanceTask = nil
        isCelebrationTransitioning = false

        guard isActive else { return }
        scheduleNextCelebration(after: celebrationResumeDelay, reason: "foreground")
    }

    /// Keeps ceremonial feedback out of an in-progress recording or editing flow.
    /// Callers use a stable reason so nested surfaces can defer independently.
    func setCelebrationPresentationDeferred(_ isDeferred: Bool, reason: String) {
        guard !reason.isEmpty else { return }

        if isDeferred {
            celebrationDeferralReasons.insert(reason)
            celebrationAdvanceTask?.cancel()
            celebrationAdvanceTask = nil
            isCelebrationTransitioning = false
            logger.info("Deferred celebrations; reasons=\(self.celebrationDeferralReasons.count)")
            return
        }

        celebrationDeferralReasons.remove(reason)
        logger.info("Cleared celebration deferral; reasons=\(self.celebrationDeferralReasons.count)")
        guard celebrationDeferralReasons.isEmpty else { return }

        // Let the outgoing sheet/cover finish its dismissal before presenting
        // the queued result on the unobstructed app surface.
        scheduleNextCelebration(after: celebrationResumeDelay, reason: "deferral")
    }

    private func presentCelebration(_ next: AppCelebration) {
        guard celebration?.deduplicationKey != next.deduplicationKey,
              !celebrationQueue.contains(where: { $0.deduplicationKey == next.deduplicationKey }) else {
            logger.debug("Ignored duplicate celebration")
            return
        }

        guard celebrationDeferralReasons.isEmpty,
              isSceneActive,
              !isCelebrationTransitioning else {
            enqueueCelebration(next)
            return
        }

        if let current = celebration, next.kind == .milestone, current.kind == .reward {
            celebrationQueue.insert(current, at: 0)
            showCelebration(next)
        } else if celebration == nil {
            showCelebration(next)
        } else {
            enqueueCelebration(next)
        }
    }

    private func enqueueCelebration(_ next: AppCelebration) {
        if next.kind == .milestone {
            celebrationQueue.insert(next, at: 0)
        } else {
            celebrationQueue.append(next)
        }
        logger.info("Enqueued celebration; queued=\(self.celebrationQueue.count)")
    }

    private func showToast(_ message: AppToastMessage) {
        toastDismissTask?.cancel()
        toast = message
        UIAccessibility.post(notification: .announcement, argument: message.text)
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: message.duration)
            guard !Task.isCancelled else { return }
            self?.toast = nil
            self?.showNextToastIfNeeded()
        }
    }

    private func showNextToastIfNeeded() {
        guard toast == nil, !toastQueue.isEmpty else { return }
        showToast(toastQueue.removeFirst())
    }

    private func showCelebration(_ next: AppCelebration) {
        guard isSceneActive, celebrationDeferralReasons.isEmpty else {
            enqueueCelebration(next)
            return
        }

        celebration = next
        logger.info("Showing celebration; queued=\(self.celebrationQueue.count)")
        let announcement = next.rewardAmount > 0
            ? "\(next.title)，获得 \(CompanionRecruitmentStore.currencyText(next.rewardAmount))"
            : next.title
        UIAccessibility.post(notification: .announcement, argument: announcement)
        AppHapticFeedback.notification(.success)
    }

    private func showNextCelebrationIfNeeded() {
        guard celebration == nil,
              isSceneActive,
              !isCelebrationTransitioning,
              celebrationDeferralReasons.isEmpty,
              !celebrationQueue.isEmpty else { return }
        showCelebration(celebrationQueue.removeFirst())
    }

    private func scheduleNextCelebration(after delay: Duration, reason: String) {
        celebrationAdvanceTask?.cancel()
        celebrationAdvanceTask = nil

        guard celebration == nil,
              isSceneActive,
              celebrationDeferralReasons.isEmpty,
              !celebrationQueue.isEmpty else { return }

        isCelebrationTransitioning = true
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.isCelebrationTransitioning = false
            self.celebrationAdvanceTask = nil
            guard self.isSceneActive,
                  self.celebration == nil,
                  self.celebrationDeferralReasons.isEmpty else { return }
            self.logger.info("Resuming celebration queue after \(reason, privacy: .public)")
            self.showNextCelebrationIfNeeded()
        }
        celebrationAdvanceTask = task
    }
}

struct AppToastView: View {
    let message: AppToastMessage

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: message.style.systemImage)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(message.style.tint)
            Text(message.text)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 42)
        .appGlassSurface(cornerRadius: 21, fillOpacity: 0.90, strokeOpacity: 0.84, shadowOpacity: 0.14)
        .accessibilityElement(children: .combine)
    }
}

struct AppInlineBanner: View {
    let style: AppToastStyle
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: style.systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(style.tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(style.tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(message)
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(style.tint)
                        .padding(.top, 3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(style.tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(style.tint.opacity(0.20), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

private struct AppCelebrationBadge: View {
    let celebration: AppCelebration

    var body: some View {
        Image("bbbucks_coin")
            .resizable()
            .scaledToFit()
            .frame(
                width: celebration.kind == .milestone ? 154 : 136,
                height: celebration.kind == .milestone ? 154 : 136
            )
            .padding(12)
            .background(Circle().fill(DesignToken.surfaceRaised))
            .overlay(
                Circle()
                    .stroke(DesignToken.primarySoft.opacity(0.72), lineWidth: 1.5)
            )
            .shadow(color: DesignToken.shadowColor.opacity(0.18), radius: 18, y: 10)
            .accessibilityHidden(true)
    }
}

struct AppCelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let celebration: AppCelebration
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(DesignToken.primary.opacity(0.055))
                .overlay(DesignToken.reward.opacity(0.035))
                .overlay(DesignToken.scrim.opacity(0.11))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                // Keep the modal surface in the hit-test tree so taps cannot
                // reach the page underneath. The background has no dismissal
                // action; only the explicit button below closes the reward.
                .allowsHitTesting(true)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: celebration.kind == .milestone ? celebration.systemImage : "sparkles")
                        .font(.system(size: 12, weight: .heavy))
                    Text(celebration.kind == .milestone ? "重要里程碑".localized : "获得奖励".localized)
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .tracking(0.8)
                }
                .foregroundStyle(DesignToken.primary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule(style: .continuous).fill(DesignToken.primarySoft.opacity(0.56)))

                AppCelebrationBadge(celebration: celebration)
                    .padding(.top, 22)
                    .scaleEffect(appeared ? 1 : 0.68)

                VStack(spacing: 8) {
                    Text(celebration.title)
                        .font(BBBFont.font(size: celebration.kind == .milestone ? 26 : 23, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(celebration.subtitle)
                        .font(BBBFont.font(size: 14, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 18)

                if celebration.rewardAmount > 0 {
                    HStack(spacing: 8) {
                        Image("bbbucks_coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                        Text("+\(celebration.rewardAmount) BB Bucks")
                    }
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.rewardText)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Capsule(style: .continuous).fill(DesignToken.rewardSoft.opacity(0.72)))
                    .overlay(Capsule(style: .continuous).stroke(DesignToken.reward.opacity(0.20), lineWidth: 1))
                    .padding(.top, 18)
                }

                Button(action: onDismiss) {
                    Text(celebration.kind == .milestone ? "收下这份纪念".localized : "收下奖励".localized)
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Capsule(style: .continuous).fill(DesignToken.primaryGradient))
                        // The whole control rectangle is actionable, not only
                        // the rendered capsule or its text glyphs.
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("app.celebration.dismiss")
                .padding(.top, 22)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 28)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                    .fill(DesignToken.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                            .stroke(DesignToken.borderSubtle, lineWidth: 1)
                    )
                    .shadow(color: DesignToken.shadowColor.opacity(0.22), radius: 28, y: 14)
            )
            .padding(.horizontal, 22)
            .scaleEffect(appeared ? 1 : 0.96)
            .contentShape(RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous))
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.72)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct AppFeedbackHostModifier: ViewModifier {
    @ObservedObject var center: AppFeedbackCenter
    let isEmbeddedHost: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hostID = UUID()
    @State private var didRegisterEmbeddedHost = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = center.toast, center.celebration == nil {
                    AppToastView(message: toast)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .top)))
                        .allowsHitTesting(false)
                        .zIndex(90)
                }
            }
            .overlay {
                if let celebration = center.celebration,
                   center.isActiveCelebrationHost(hostID, isEmbedded: isEmbeddedHost) {
                    AppCelebrationView(
                        celebration: celebration,
                        onDismiss: center.dismissCelebration
                    )
                    .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.98)))
                    .zIndex(100)
                }
            }
            .animation(reduceMotion ? .linear(duration: 0.16) : .easeOut(duration: 0.24), value: center.toast?.id)
            .animation(reduceMotion ? .linear(duration: 0.16) : .easeOut(duration: 0.28), value: center.celebration?.id)
            .onAppear {
                guard isEmbeddedHost, !didRegisterEmbeddedHost else { return }
                didRegisterEmbeddedHost = true
                center.registerEmbeddedCelebrationHost(hostID)
            }
            .onDisappear {
                guard isEmbeddedHost, didRegisterEmbeddedHost else { return }
                didRegisterEmbeddedHost = false
                center.unregisterEmbeddedCelebrationHost(hostID)
            }
    }
}

extension View {
    @MainActor
    func appFeedbackHost(_ center: AppFeedbackCenter, isEmbedded: Bool = false) -> some View {
        modifier(AppFeedbackHostModifier(center: center, isEmbeddedHost: isEmbedded))
    }
}

/// App-wide user-facing date and clock formats.
/// Keep persistence keys, exported timestamps, and elapsed durations separate.
enum AppDateTimeFormat {
    static func date(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .locale(AppLocalization.locale)
        )
    }

    static func time(
        _ date: Date,
        locale: Locale = AppLocalization.locale
    ) -> String {
        var localeComponents = Locale.Components(locale: locale)
        localeComponents.hourCycle = .zeroToTwentyThree
        let clockLocale = Locale(components: localeComponents)

        return date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(clockLocale)
        )
    }

    static func timeRange(
        from start: Date,
        to end: Date?,
        locale: Locale = AppLocalization.locale
    ) -> String {
        let startText = time(start, locale: locale)
        guard let end else {
            return AppLocalization.format("%@–进行中", startText)
        }
        return "\(startText)–\(time(end, locale: locale))"
    }

    static func hour(_ hour: Int) -> String {
        String(format: "%02d:00", min(max(hour, 0), 23))
    }

    static func hourRange(from startHour: Int, to endHour: Int) -> String {
        let startText = hour(startHour)
        guard startHour != endHour else { return startText }
        return "\(startText)–\(hour(endHour))"
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(AppLocalization.locale)
        )
    }
}

struct AppModalBackdrop: View {
    let bodyColor: Color
    let accent: Color

    var body: some View {
        Rectangle()
            .fill(.thickMaterial)
            .overlay(
                LinearGradient(
                    colors: [
                        bodyColor.opacity(0.24),
                        accent.opacity(0.16),
                        DesignToken.glassFill.opacity(0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                LinearGradient(
                    colors: [
                        DesignToken.scrim.opacity(0.10),
                        DesignToken.scrim.opacity(0.03),
                        DesignToken.scrim.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        DesignToken.glassFill.opacity(0.24),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blendMode(.softLight)
            )
    }
}

struct AppPageCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
                .contentShape(Rectangle())
        }
        // The navigation bar supplies the single page-button container. Keeping
        // this label plain prevents a second rounded rectangle inside it.
        .buttonStyle(.plain)
        .accessibilityLabel("关闭")
    }
}

struct AppPageStandaloneButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void
    var size: CGFloat = DesignToken.minimumTapSize
    var iconSize: CGFloat = 20

    var body: some View {
        let cornerRadius = min(18, size * 0.36)

        return Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(width: size, height: size)
                .glassEffect(
                    .regular
                        .tint(DesignToken.glassFill.opacity(0.14))
                        .interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

enum BabyAgeFormatter {
    static func components(
        birthDate: Date,
        on date: Date,
        calendar: Calendar = .current
    ) -> (months: Int, days: Int) {
        let start = calendar.startOfDay(for: birthDate)
        let end = calendar.startOfDay(for: date)
        guard end >= start else { return (0, 0) }

        let components = calendar.dateComponents([.month, .day], from: start, to: end)
        return (
            months: max(components.month ?? 0, 0),
            days: max(components.day ?? 0, 0)
        )
    }

    static func displayText(
        birthDate: Date,
        on date: Date,
        calendar: Calendar = .current
    ) -> String {
        let age = components(birthDate: birthDate, on: date, calendar: calendar)
        if age.months == 0 {
            return AppQuantityFormat.days(age.days)
        }
        if age.days == 0 {
            return AppLocalization.format(
                age.months == 1 ? "quantity.age_month.one" : "quantity.age_month.other",
                age.months
            )
        }
        return AppLocalization.format("quantity.age.months_days", age.months, age.days)
    }
}

enum RecordHomeMode: String, CaseIterable, Identifiable {
    case basic
    case easy

    static let storageKey = "record_home_mode_v1"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "基础记录".localized
        case .easy: return "EASY 循环".localized
        }
    }

    var subtitle: String {
        switch self {
        case .basic: return "适合快速记录单项喂养、尿布、睡眠。".localized
        case .easy: return "适合按吃、玩、睡维护完整照护节奏。".localized
        }
    }

    var shortTitle: String {
        switch self {
        case .basic: return "基础".localized
        case .easy: return "EASY"
        }
    }
}

enum EasyCyclePhase: String, Codable, CaseIterable, Identifiable {
    case eat
    case activity
    case sleep
    case yearning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eat: return "喂养".localized
        case .activity: return "活动".localized
        case .sleep: return "睡眠".localized
        case .yearning: return "状态".localized
        }
    }

    var letter: String {
        switch self {
        case .eat: return "E"
        case .activity: return "A"
        case .sleep: return "S"
        case .yearning: return "Y"
        }
    }

    var next: EasyCyclePhase? {
        switch self {
        case .eat: return .activity
        case .activity: return .sleep
        case .sleep: return .yearning
        case .yearning: return nil
        }
    }
}

enum EasyCycleStatus: String, Codable {
    case active
    case readyToPublish
    case published
}

enum EasyCycleMutationReason: String, Codable {
    case backfilledRecordSplit
    case recordChange
    case userMerged
}

private extension EasyCyclePhase {
    var progressionRank: Int {
        switch self {
        case .eat: return 0
        case .activity: return 1
        case .sleep: return 2
        case .yearning: return 3
        }
    }
}

enum EasyCycleLinkedRecordType: String, Codable {
    case feeding
    case care
}

struct EasyCycleRecordLink: Identifiable, Codable, Hashable {
    var id: String { "\(type.rawValue)-\(recordID.uuidString)" }
    var type: EasyCycleLinkedRecordType
    var recordID: UUID
    var phase: EasyCyclePhase
}

struct EasyCycleSplitNotice: Identifiable, Codable, Hashable {
    struct CycleRange: Identifiable, Codable, Hashable {
        let id: UUID
        let startedAt: Date
        let endedAt: Date?
    }

    let id: UUID
    let sourceRecordedAt: Date
    let sourcePhase: EasyCyclePhase
    let replacedCycle: CycleRange
    let replacementCycles: [CycleRange]
}

struct EasyCycle: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var currentPhase: EasyCyclePhase
    var status: EasyCycleStatus
    var activityStartedAt: Date?
    var activityEndedAt: Date?
    var note: String
    var linkedRecords: [EasyCycleRecordLink]
    var publishedAt: Date?
    var updatedAt: Date
    var supersededAt: Date?
    var supersedes: [UUID]?
    var supersededBy: [UUID]?
    var mutationReason: EasyCycleMutationReason?
    var pendingSplitReviewID: UUID?
    var groupingLockedAt: Date?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        currentPhase: EasyCyclePhase = .eat,
        status: EasyCycleStatus = .active,
        activityStartedAt: Date? = nil,
        activityEndedAt: Date? = nil,
        note: String = "",
        linkedRecords: [EasyCycleRecordLink] = [],
        publishedAt: Date? = nil,
        updatedAt: Date = Date(),
        supersededAt: Date? = nil,
        supersedes: [UUID]? = nil,
        supersededBy: [UUID]? = nil,
        mutationReason: EasyCycleMutationReason? = nil,
        pendingSplitReviewID: UUID? = nil,
        groupingLockedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.currentPhase = currentPhase
        self.status = status
        self.activityStartedAt = activityStartedAt
        self.activityEndedAt = activityEndedAt
        self.note = note
        self.linkedRecords = linkedRecords
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.supersededAt = supersededAt
        self.supersedes = supersedes
        self.supersededBy = supersededBy
        self.mutationReason = mutationReason
        self.pendingSplitReviewID = pendingSplitReviewID
        self.groupingLockedAt = groupingLockedAt
    }

    var isOpen: Bool {
        supersededAt == nil && status != .published
    }

    var isCurrentVersion: Bool {
        supersededAt == nil
    }
}

@MainActor
final class EasyCycleStore: ObservableObject {
    static let shared = EasyCycleStore()

    @Published private(set) var cycles: [EasyCycle] = [] {
        didSet { persist() }
    }
    @Published private(set) var pendingSplitNotice: EasyCycleSplitNotice? {
        didSet { persistPendingSplitNotice() }
    }

    private let defaults: UserDefaults
    private let appGroupDefaults: UserDefaults?
    private let key: String
    private let sourceRecordsKey: String
    private let pendingSplitNoticeKey: String
    private let feedingCycleTimeout: TimeInterval = 2 * 60 * 60
    private let minimumSleepMinutesForCycle = 1
    private var hasFinishedInitialization = false
    private var sourceRecords: [String: EasyCycleSourceRecord] = [:]
    private var hasInitializedSourceRecords = false

    init(
        defaults: UserDefaults = .standard,
        appGroupDefaults: UserDefaults? = UserDefaults(suiteName: WidgetStorageKey.appGroupID),
        storageKey: String = "easy_cycles_v1"
    ) {
        self.defaults = defaults
        self.appGroupDefaults = appGroupDefaults
        self.key = storageKey
        self.sourceRecordsKey = "\(storageKey)_source_records_v2"
        self.pendingSplitNoticeKey = "\(storageKey)_pending_split_notice_v2"
        loadCycles()
        loadSourceRecords()
        loadPendingSplitNotice()
        hasFinishedInitialization = true
    }

    func rebuild(from feedingSessions: [FeedingSession], careRecords: [CareRecord]) {
        let now = Date()
        let validSessions = feedingSessions.filter {
            $0.hasData && $0.eventDate <= now
        }
        let validCareRecords = careRecords.filter { $0.recordedAt <= now }
        let nextSourceRecords = makeSourceRecords(
            feedingSessions: validSessions,
            careRecords: validCareRecords
        )
        guard hasInitializedSourceRecords else {
            migrateToIncrementalCycles(
                feedingSessions: validSessions,
                careRecords: validCareRecords,
                sourceRecords: nextSourceRecords
            )
            return
        }
        guard sourceRecords != nextSourceRecords else { return }

        reconcileIncrementally(with: nextSourceRecords)
    }

    func cycles(on date: Date) -> [EasyCycle] {
        cycles
            .filter(\.isCurrentVersion)
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
            .filter { $0.linkedRecords.isEmpty || hasStarterRecord($0) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func currentCycle(on date: Date = Date()) -> EasyCycle? {
        let sameDayCycle = cycles
            .filter(\.isCurrentVersion)
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
            .filter { $0.linkedRecords.isEmpty || hasStarterRecord($0) }
            .sorted { $0.startedAt > $1.startedAt }
            .first
        if let sameDayCycle { return sameDayCycle }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        return cycles
            .filter(\.isCurrentVersion)
            .filter { $0.startedAt < dayEnd }
            .filter { cycle in
                guard let endedAt = cycle.endedAt else { return true }
                return endedAt >= dayStart
            }
            .filter { $0.linkedRecords.isEmpty || hasStarterRecord($0) }
            .max { $0.startedAt < $1.startedAt }
    }

    func performPrimaryAction(now: Date = Date(), startedAt: Date? = nil) {
        if let index = primaryActionCycleIndex(on: now) {
            advanceCycle(at: index, now: now)
        } else {
            cycles.insert(EasyCycle(startedAt: startedAt ?? now, updatedAt: now), at: 0)
        }
        sortCycles()
    }

    func updateNote(for id: UUID, note: String) {
        guard let index = cycles.firstIndex(where: { $0.id == id && $0.isCurrentVersion }) else { return }
        cycles[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        cycles[index].updatedAt = Date()
    }

    func replaceLinks(for id: UUID, links: [EasyCycleRecordLink]) {
        guard let index = cycles.firstIndex(where: { $0.id == id && $0.isCurrentVersion }) else { return }
        cycles[index].linkedRecords = Array(Set(links)).sorted { $0.id < $1.id }
        normalizePhaseProgress(at: index, eventDate: Date())
        cycles[index].updatedAt = Date()
    }

    func ensureCycle(on date: Date, startedAt: Date, links: [EasyCycleRecordLink]) {
        let normalizedLinks = Array(Set(links)).sorted { $0.id < $1.id }
        guard !normalizedLinks.isEmpty else { return }
        guard normalizedLinks.contains(where: { $0.phase == .eat || $0.phase == .activity }) else { return }

        let calendar = Calendar.current
        if let index = cycles.indices
            .filter({
                cycles[$0].isCurrentVersion
                    && calendar.isDate(cycles[$0].startedAt, inSameDayAs: date)
            })
            .sorted(by: { cycles[$0].startedAt > cycles[$1].startedAt })
            .first {
            guard Set(cycles[index].linkedRecords) != Set(normalizedLinks) else { return }
            cycles[index].linkedRecords = normalizedLinks
            cycles[index].startedAt = min(cycles[index].startedAt, startedAt)
            normalizePhaseProgress(at: index, eventDate: startedAt)
            cycles[index].updatedAt = Date()
            sortCycles()
            return
        }

        var cycle = EasyCycle(startedAt: startedAt, linkedRecords: normalizedLinks, updatedAt: Date())
        normalizePhaseProgress(for: &cycle, eventDate: startedAt)
        cycles.insert(cycle, at: 0)
        sortCycles()
    }

    func trackFeedingSession(_ session: FeedingSession) {
        // EASY cycles are derived from the full record set. Record stores trigger
        // a rebuild from RecordHomeView, so this legacy incremental hook is inert.
    }

    func trackCareRecord(_ record: CareRecord) {
        // EASY cycles are derived from the full record set. Record stores trigger
        // a rebuild from RecordHomeView, so this legacy incremental hook is inert.
    }

    func removeRecordLink(type: EasyCycleLinkedRecordType, recordID: UUID) {
        // Deletions are handled by a full rebuild from the remaining fact records.
    }

    func importCycles(_ incomingCycles: [EasyCycle]) {
        let existingIDs = Set(cycles.map(\.id))
        cycles = (cycles + incomingCycles.filter { !existingIDs.contains($0.id) })
            .sorted { $0.startedAt > $1.startedAt }
        sourceRecords = [:]
        hasInitializedSourceRecords = false
        persistSourceRecords()
    }

    func acknowledgeSplit(_ noticeID: UUID) {
        guard pendingSplitNotice?.id == noticeID else { return }
        var nextCycles = cycles
        for index in nextCycles.indices where nextCycles[index].pendingSplitReviewID == noticeID {
            nextCycles[index].pendingSplitReviewID = nil
            nextCycles[index].updatedAt = Date()
        }
        cycles = nextCycles
        pendingSplitNotice = nil
    }

    func mergeSplitBack(_ noticeID: UUID) {
        guard let notice = pendingSplitNotice, notice.id == noticeID,
              let replacedIndex = cycles.firstIndex(where: { $0.id == notice.replacedCycle.id }) else {
            return
        }

        let replacementIDs = Set(notice.replacementCycles.map(\.id))
        let replacementCycles = cycles.filter { replacementIDs.contains($0.id) && $0.isCurrentVersion }
        guard !replacementCycles.isEmpty else {
            pendingSplitNotice = nil
            return
        }

        let now = Date()
        let combinedLinks = Array(Set(replacementCycles.flatMap(\.linkedRecords)))
            .sorted { $0.id < $1.id }
        let combinedSources = combinedLinks.compactMap { sourceRecords[$0.id] }

        var restored = cycles[replacedIndex]
        restored.supersededAt = nil
        restored.supersededBy = nil
        restored.linkedRecords = combinedLinks
        restored.startedAt = combinedSources.map(\.startAt).min() ?? restored.startedAt
        restored.endedAt = combinedSources
            .filter { $0.phase == .sleep }
            .map(\.endAt)
            .max()
        restored.updatedAt = now
        restored.mutationReason = .userMerged
        restored.pendingSplitReviewID = nil
        restored.groupingLockedAt = now
        normalizePhaseProgress(for: &restored, eventDate: restored.startedAt)

        var nextCycles = cycles
        nextCycles[replacedIndex] = restored
        for index in nextCycles.indices where replacementIDs.contains(nextCycles[index].id) {
            nextCycles[index].supersededAt = now
            nextCycles[index].supersededBy = [restored.id]
            nextCycles[index].pendingSplitReviewID = nil
            nextCycles[index].mutationReason = .userMerged
            nextCycles[index].updatedAt = now
        }
        cycles = nextCycles.sorted { $0.startedAt > $1.startedAt }
        pendingSplitNotice = nil
    }

    private func advanceCycle(at index: Int, now: Date) {
        switch cycles[index].currentPhase {
        case .eat:
            cycles[index].currentPhase = .activity
            cycles[index].activityStartedAt = cycles[index].activityStartedAt ?? now
        case .activity:
            cycles[index].currentPhase = .sleep
            cycles[index].activityEndedAt = cycles[index].activityEndedAt ?? now
        case .sleep:
            cycles[index].currentPhase = .yearning
            cycles[index].endedAt = cycles[index].endedAt ?? now
            cycles[index].status = .readyToPublish
        case .yearning:
            cycles[index].status = .published
            cycles[index].publishedAt = cycles[index].publishedAt ?? now
            cycles[index].endedAt = cycles[index].endedAt ?? now
        }
        cycles[index].updatedAt = now
    }

    private func primaryActionCycleIndex(on date: Date) -> Int? {
        let calendar = Calendar.current
        let dayIndices = cycles.indices
            .filter {
                cycles[$0].isCurrentVersion
                    && calendar.isDate(cycles[$0].startedAt, inSameDayAs: date)
                    && cycles[$0].status != .published
            }
            .sorted { cycles[$0].startedAt > cycles[$1].startedAt }
        guard let latestIndex = dayIndices.first else { return nil }

        if cycles[latestIndex].status == .readyToPublish || cycleHasSleep(at: latestIndex) {
            return latestIndex
        }

        if date.timeIntervalSince(cycles[latestIndex].startedAt) > hardCycleTimeout(asOf: date) {
            closeTimedOutCycle(at: latestIndex, before: date)
            return nil
        }

        return latestIndex
    }

    private func manualCyclesToKeep(afterRebuilding rebuiltCycles: [EasyCycle]) -> [EasyCycle] {
        let calendar = Calendar.current
        return cycles.filter { cycle in
            guard cycle.isCurrentVersion, cycle.linkedRecords.isEmpty else { return false }
            return !rebuiltCycles.contains { rebuilt in
                calendar.isDate(rebuilt.startedAt, inSameDayAs: cycle.startedAt)
                    && rebuilt.startedAt >= cycle.startedAt
            }
        }
    }

    private func currentOpenCycleIndex(on date: Date) -> Int? {
        let calendar = Calendar.current
        let dayIndices = cycles.indices
            .filter {
                cycles[$0].isCurrentVersion
                    && calendar.isDate(cycles[$0].startedAt, inSameDayAs: date)
                    && cycles[$0].status != .published
            }
            .sorted { cycles[$0].startedAt > cycles[$1].startedAt }
        guard let latestIndex = dayIndices.first else { return nil }
        guard !cycleHasSleep(at: latestIndex) else { return nil }

        if date.timeIntervalSince(cycles[latestIndex].startedAt) > hardCycleTimeout(asOf: date) {
            closeTimedOutCycle(at: latestIndex, before: date)
            return nil
        }

        return latestIndex
    }

    private func closeTimedOutCycle(at index: Int, before date: Date) {
        guard cycles.indices.contains(index), !cycleHasSleep(at: index) else { return }
        let end = max(cycles[index].startedAt, date.addingTimeInterval(-1))
        cycles[index].endedAt = cycles[index].endedAt ?? end
        cycles[index].currentPhase = .sleep
        cycles[index].updatedAt = max(cycles[index].updatedAt, end)
    }

    private func appendRecordLink(
        _ link: EasyCycleRecordLink,
        eventDate: Date,
        updatedAt: Date,
        canCreateCycle: Bool = true,
        endedAt: Date? = nil
    ) {
        guard eventDate <= Date() else { return }
        let index: Int
        if let existingIndex = currentOpenCycleIndex(on: eventDate) {
            index = existingIndex
        } else {
            guard canCreateCycle else { return }
            cycles.insert(EasyCycle(startedAt: eventDate, updatedAt: updatedAt), at: 0)
            sortCycles()
            guard let createdIndex = cycles.firstIndex(where: {
                Calendar.current.isDate($0.startedAt, inSameDayAs: eventDate) && $0.startedAt == eventDate
            }) else { return }
            index = createdIndex
        }

        if !cycles[index].linkedRecords.contains(link) {
            cycles[index].linkedRecords.append(link)
        }
        cycles[index].linkedRecords = Array(Set(cycles[index].linkedRecords)).sorted { $0.id < $1.id }
        normalizePhaseProgress(at: index, eventDate: eventDate)
        if let endedAt {
            cycles[index].endedAt = endedAt
        }
        cycles[index].updatedAt = max(updatedAt, cycles[index].updatedAt)
        sortCycles()
    }

    private func migrateToIncrementalCycles(
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord],
        sourceRecords nextSourceRecords: [String: EasyCycleSourceRecord]
    ) {
        var existingByID: [UUID: EasyCycle] = [:]
        for cycle in cycles where cycle.isCurrentVersion {
            existingByID[cycle.id] = cycle
        }

        let rebuiltCycles = buildCycles(from: feedingSessions, careRecords: careRecords)
            .map { rebuilt in
                guard let existing = existingByID[rebuilt.id] else { return rebuilt }
                return rebuilt.preservingUserState(from: existing)
            }
        let manualCycles = manualCyclesToKeep(afterRebuilding: rebuiltCycles)
        let historicalVersions = cycles.filter { !$0.isCurrentVersion }
        let nextCycles = (rebuiltCycles + manualCycles + historicalVersions)
            .sorted { $0.startedAt > $1.startedAt }

        sourceRecords = nextSourceRecords
        hasInitializedSourceRecords = true
        persistSourceRecords()
        guard cycles != nextCycles else { return }
        cycles = nextCycles
    }

    private func reconcileIncrementally(with nextSourceRecords: [String: EasyCycleSourceRecord]) {
        let allKeys = Set(sourceRecords.keys).union(nextSourceRecords.keys)
        let changedKeys = Set(allKeys.filter { sourceRecords[$0] != nextSourceRecords[$0] })
        guard !changedKeys.isEmpty else { return }

        let currentCycles = cycles
            .filter(\.isCurrentVersion)
            .filter { !$0.linkedRecords.isEmpty }
            .sorted { $0.startedAt < $1.startedAt }
        var affectedCycleIDs = Set(currentCycles.filter { cycle in
            cycle.linkedRecords.contains { changedKeys.contains($0.id) }
        }.map(\.id))

        let changedDates = changedKeys.flatMap { key -> [Date] in
            [sourceRecords[key]?.startAt, nextSourceRecords[key]?.startAt].compactMap { $0 }
        }
        for date in changedDates {
            if let previousIndex = currentCycles.lastIndex(where: { $0.startedAt <= date }) {
                affectedCycleIDs.insert(currentCycles[previousIndex].id)
                if previousIndex > currentCycles.startIndex {
                    affectedCycleIDs.insert(currentCycles[currentCycles.index(before: previousIndex)].id)
                }
                let nextIndex = currentCycles.index(after: previousIndex)
                if nextIndex < currentCycles.endIndex {
                    affectedCycleIDs.insert(currentCycles[nextIndex].id)
                }
            } else if let first = currentCycles.first {
                affectedCycleIDs.insert(first.id)
            }
        }

        if let firstAffectedIndex = currentCycles.firstIndex(where: { affectedCycleIDs.contains($0.id) }) {
            let nextIndex = currentCycles.index(after: firstAffectedIndex)
            if nextIndex < currentCycles.endIndex {
                affectedCycleIDs.insert(currentCycles[nextIndex].id)
            }
        }
        if let lastAffectedIndex = currentCycles.lastIndex(where: { affectedCycleIDs.contains($0.id) }),
           lastAffectedIndex > currentCycles.startIndex {
            affectedCycleIDs.insert(currentCycles[currentCycles.index(before: lastAffectedIndex)].id)
        }

        let affectedCycles = currentCycles.filter { affectedCycleIDs.contains($0.id) }
        var localSourceKeys = Set(affectedCycles.flatMap { $0.linkedRecords.map(\.id) })
        localSourceKeys.formUnion(changedKeys)
        let localSources = localSourceKeys.compactMap { nextSourceRecords[$0] }
        let candidateCycles = buildCycles(from: localSources)

        let components = mutationComponents(
            existingCycles: affectedCycles,
            candidateCycles: candidateCycles
        )
        var nextCycles = cycles
        var generatedNotice: EasyCycleSplitNotice?
        let now = Date()

        for component in components {
            let oldCycles = component.existingIndices.map { affectedCycles[$0] }
            let candidates = component.candidateIndices.map { candidateCycles[$0] }

            switch (oldCycles.count, candidates.count) {
            case (1, 1):
                guard let old = oldCycles.first, let candidate = candidates.first,
                      let index = nextCycles.firstIndex(where: { $0.id == old.id }) else {
                    continue
                }
                var updated = candidate.replacingIdentity(with: old.id)
                    .preservingUserState(from: old)
                updated.supersedes = old.supersedes
                updated.mutationReason = .recordChange
                updated.groupingLockedAt = old.groupingLockedAt
                nextCycles[index] = updated

            case (1, let newCount) where newCount > 1:
                guard let old = oldCycles.first,
                      let oldIndex = nextCycles.firstIndex(where: { $0.id == old.id }) else {
                    continue
                }
                let shouldRequestReview = generatedNotice == nil
                let noticeID = shouldRequestReview ? UUID() : nil
                let anchorLinkID = old.linkedRecords
                    .first(where: { $0.phase == .eat || $0.phase == .activity })?
                    .id
                let replacements = candidates.map { candidate -> EasyCycle in
                    var replacement = candidate.replacingIdentity(with: UUID())
                    replacement.supersedes = [old.id]
                    replacement.mutationReason = .backfilledRecordSplit
                    replacement.pendingSplitReviewID = noticeID
                    if let anchorLinkID,
                       replacement.linkedRecords.contains(where: { $0.id == anchorLinkID }) {
                        replacement = replacement.preservingUserState(from: old)
                        replacement.pendingSplitReviewID = noticeID
                        replacement.supersedes = [old.id]
                        replacement.mutationReason = .backfilledRecordSplit
                    }
                    return replacement
                }
                let replacementIDs = replacements.map(\.id)
                nextCycles[oldIndex].supersededAt = now
                nextCycles[oldIndex].supersededBy = replacementIDs
                nextCycles[oldIndex].mutationReason = .backfilledRecordSplit
                nextCycles[oldIndex].updatedAt = now
                nextCycles.append(contentsOf: replacements)

                if let noticeID, let source = changedKeys
                    .compactMap({ nextSourceRecords[$0] })
                    .sorted(by: { $0.startAt < $1.startAt })
                    .first {
                    generatedNotice = EasyCycleSplitNotice(
                        id: noticeID,
                        sourceRecordedAt: source.startAt,
                        sourcePhase: source.phase,
                        replacedCycle: .init(
                            id: old.id,
                            startedAt: old.startedAt,
                            endedAt: cycleEndDate(old, sourceRecords: sourceRecords)
                        ),
                        replacementCycles: replacements
                            .sorted { $0.startedAt < $1.startedAt }
                            .map {
                                .init(
                                    id: $0.id,
                                    startedAt: $0.startedAt,
                                    endedAt: cycleEndDate($0, sourceRecords: nextSourceRecords)
                                )
                            }
                    )
                }

            default:
                let oldIDs = oldCycles.map(\.id)
                let replacementIDs = candidates.map { _ in UUID() }
                for old in oldCycles {
                    guard let index = nextCycles.firstIndex(where: { $0.id == old.id }) else { continue }
                    nextCycles[index].supersededAt = now
                    nextCycles[index].supersededBy = replacementIDs
                    nextCycles[index].mutationReason = .recordChange
                    nextCycles[index].updatedAt = now
                }
                for (candidate, replacementID) in zip(candidates, replacementIDs) {
                    var replacement = candidate.replacingIdentity(with: replacementID)
                    replacement.supersedes = oldIDs.isEmpty ? nil : oldIDs
                    replacement.mutationReason = .recordChange
                    nextCycles.append(replacement)
                }
            }
        }

        sourceRecords = nextSourceRecords
        hasInitializedSourceRecords = true
        persistSourceRecords()
        if let generatedNotice {
            pendingSplitNotice = generatedNotice
        }
        let sortedCycles = nextCycles.sorted { $0.startedAt > $1.startedAt }
        if cycles != sortedCycles {
            cycles = sortedCycles
        }
    }

    private func mutationComponents(
        existingCycles: [EasyCycle],
        candidateCycles: [EasyCycle]
    ) -> [EasyCycleMutationComponent] {
        let existingLinkSets = existingCycles.map { Set($0.linkedRecords.map(\.id)) }
        let candidateLinkSets = candidateCycles.map { Set($0.linkedRecords.map(\.id)) }
        var remainingExisting = Set(existingCycles.indices)
        var remainingCandidates = Set(candidateCycles.indices)
        var components: [EasyCycleMutationComponent] = []

        while let seed = remainingExisting.first {
            var existingComponent: Set<Int> = [seed]
            var candidateComponent: Set<Int> = []
            var didGrow = true
            while didGrow {
                didGrow = false
                for candidateIndex in remainingCandidates where candidateComponent.contains(candidateIndex) == false {
                    if existingComponent.contains(where: {
                        !existingLinkSets[$0].isDisjoint(with: candidateLinkSets[candidateIndex])
                    }) {
                        candidateComponent.insert(candidateIndex)
                        didGrow = true
                    }
                }
                for existingIndex in remainingExisting where existingComponent.contains(existingIndex) == false {
                    if candidateComponent.contains(where: {
                        !candidateLinkSets[$0].isDisjoint(with: existingLinkSets[existingIndex])
                    }) {
                        existingComponent.insert(existingIndex)
                        didGrow = true
                    }
                }
            }
            remainingExisting.subtract(existingComponent)
            remainingCandidates.subtract(candidateComponent)
            components.append(.init(
                existingIndices: existingComponent.sorted(),
                candidateIndices: candidateComponent.sorted()
            ))
        }

        for candidateIndex in remainingCandidates.sorted() {
            if let nearestExistingIndex = existingCycles.indices.min(by: {
                abs(existingCycles[$0].startedAt.timeIntervalSince(candidateCycles[candidateIndex].startedAt))
                    < abs(existingCycles[$1].startedAt.timeIntervalSince(candidateCycles[candidateIndex].startedAt))
            }),
               let componentIndex = components.firstIndex(where: {
                   $0.existingIndices.contains(nearestExistingIndex)
               }) {
                let component = components[componentIndex]
                components[componentIndex] = .init(
                    existingIndices: component.existingIndices,
                    candidateIndices: (component.candidateIndices + [candidateIndex]).sorted()
                )
            } else {
                components.append(.init(existingIndices: [], candidateIndices: [candidateIndex]))
            }
        }
        return components
    }

    private func cycleEndDate(
        _ cycle: EasyCycle,
        sourceRecords records: [String: EasyCycleSourceRecord]
    ) -> Date? {
        cycle.endedAt ?? cycle.linkedRecords
            .compactMap { records[$0.id]?.endAt }
            .max()
    }

    private func buildCycles(from feedingSessions: [FeedingSession], careRecords: [CareRecord]) -> [EasyCycle] {
        buildCycles(from: Array(makeSourceRecords(
            feedingSessions: feedingSessions,
            careRecords: careRecords
        ).values))
    }

    private func buildCycles(from sourceRecords: [EasyCycleSourceRecord]) -> [EasyCycle] {
        var completedDrafts: [EasyCycleDraft] = []
        var currentDraft: EasyCycleDraft?

        for event in sourceRecords
            .map(\.event)
            .sorted(by: EasyCycleEvent.isOrderedBefore) {
            switch event.phase {
            case .eat, .activity:
                if let draft = currentDraft {
                    if draft.hasSleep {
                        completedDrafts.append(draft)
                        currentDraft = nil
                    } else if shouldStartNewCycle(for: event, after: draft) {
                        completedDrafts.append(draft.closedForMissingSleep(before: event.startAt))
                        currentDraft = nil
                    }
                }

                if currentDraft == nil {
                    currentDraft = EasyCycleDraft(startedAt: event.startAt)
                }

                currentDraft?.append(event)

            case .sleep:
                guard var draft = currentDraft,
                      draft.hasStarterRecord,
                      event.startAt >= draft.startedAt else {
                    continue
                }
                draft.append(event)
                currentDraft = draft

            case .yearning:
                continue
            }
        }

        if let currentDraft {
            completedDrafts.append(currentDraft)
        }

        let cycles = completedDrafts
            .compactMap { $0.finalizedCycle(id: stableCycleID(for: $0)) }
            .filter(hasStarterRecord)
            .sorted { $0.startedAt > $1.startedAt }

        return cycles
    }

    private func makeSourceRecords(
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord]
    ) -> [String: EasyCycleSourceRecord] {
        var records: [String: EasyCycleSourceRecord] = [:]

        for session in feedingSessions where session.hasData {
            let startAt = session.eventDate
            guard startAt <= Date() else { continue }
            let endAt = max(session.endAt ?? session.createdAt, startAt)
            let source = EasyCycleSourceRecord(
                type: .feeding,
                recordID: session.id,
                phase: .eat,
                startAt: startAt,
                endAt: endAt
            )
            records[source.id] = source
        }

        for record in careRecords where record.recordedAt <= Date() {
            let phase: EasyCyclePhase
            let endAt: Date
            switch record.kind {
            case .diaper, .activity:
                phase = .activity
                endAt = record.recordedAt
            case .sleep:
                guard let duration = SleepRecordFormatter.durationMinutes(from: record.detail),
                      duration >= minimumSleepMinutesForCycle else {
                    continue
                }
                phase = .sleep
                endAt = max(
                    SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration),
                    record.recordedAt
                )
            }
            let source = EasyCycleSourceRecord(
                type: .care,
                recordID: record.id,
                phase: phase,
                startAt: record.recordedAt,
                endAt: endAt
            )
            records[source.id] = source
        }
        return records
    }

    private func shouldStartNewCycle(for event: EasyCycleEvent, after draft: EasyCycleDraft) -> Bool {
        if event.startAt.timeIntervalSince(draft.lastStarterAt) > hardCycleTimeout(asOf: event.startAt) {
            return true
        }

        if event.phase == .eat,
           let lastEatAt = draft.lastEatAt,
           event.startAt.timeIntervalSince(lastEatAt) > feedingCycleTimeout {
            return true
        }

        return false
    }

    private func easyCycleEvents(
        from feedingSessions: [FeedingSession],
        careRecords: [CareRecord]
    ) -> [EasyCycleEvent] {
        let feedingEvents = feedingSessions.compactMap { session -> EasyCycleEvent? in
            guard session.hasData else { return nil }
            let startAt = session.eventDate
            guard startAt <= Date() else { return nil }
            let endAt = max(session.endAt ?? session.createdAt, startAt)
            return EasyCycleEvent(
                link: EasyCycleRecordLink(type: .feeding, recordID: session.id, phase: .eat),
                phase: .eat,
                startAt: startAt,
                endAt: endAt
            )
        }

        let careEvents = careRecords.compactMap { record -> EasyCycleEvent? in
            guard record.recordedAt <= Date() else { return nil }
            switch record.kind {
            case .diaper, .activity:
                return EasyCycleEvent(
                    link: EasyCycleRecordLink(type: .care, recordID: record.id, phase: .activity),
                    phase: .activity,
                    startAt: record.recordedAt,
                    endAt: record.recordedAt
                )
            case .sleep:
                guard let duration = SleepRecordFormatter.durationMinutes(from: record.detail),
                      duration >= minimumSleepMinutesForCycle else {
                    return nil
                }
                let endAt = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration)
                return EasyCycleEvent(
                    link: EasyCycleRecordLink(type: .care, recordID: record.id, phase: .sleep),
                    phase: .sleep,
                    startAt: record.recordedAt,
                    endAt: max(endAt, record.recordedAt)
                )
            }
        }

        return (feedingEvents + careEvents).sorted { lhs, rhs in
            if lhs.startAt != rhs.startAt {
                return lhs.startAt < rhs.startAt
            }
            return lhs.sortPriority < rhs.sortPriority
        }
    }

    private func normalizePhaseProgress(at index: Int, eventDate: Date) {
        guard cycles.indices.contains(index) else { return }
        normalizePhaseProgress(for: &cycles[index], eventDate: eventDate)
    }

    private func normalizePhaseProgress(for cycle: inout EasyCycle, eventDate: Date) {
        let phases = Set(cycle.linkedRecords.map(\.phase))
        if phases.contains(.sleep) {
            cycle.currentPhase = .yearning
            return
        }
        if phases.contains(.activity) {
            cycle.currentPhase = .sleep
            cycle.endedAt = nil
            cycle.activityEndedAt = cycle.activityEndedAt ?? eventDate
            return
        }
        if phases.contains(.eat) {
            cycle.currentPhase = .activity
            cycle.endedAt = nil
            cycle.activityStartedAt = cycle.activityStartedAt ?? eventDate
            return
        }
        cycle.currentPhase = .eat
        cycle.endedAt = nil
    }

    private func cycleHasSleep(at index: Int) -> Bool {
        guard cycles.indices.contains(index) else { return false }
        return cycles[index].linkedRecords.contains { $0.phase == .sleep }
    }

    private func hasStarterRecord(_ cycle: EasyCycle) -> Bool {
        cycle.linkedRecords.contains { $0.phase == .eat || $0.phase == .activity }
    }

    private func hardCycleTimeout(asOf date: Date) -> TimeInterval {
        TimeInterval(Self.maxWakeWindowMinutes(ageMonths: babyAgeMonths(asOf: date)) * 60)
    }

    private func babyAgeMonths(asOf date: Date) -> Int {
        let birthDate = BabyProfileStore.shared.currentProfile.birthDate
        return max(Calendar.current.dateComponents([.month], from: birthDate, to: date).month ?? 0, 0)
    }

    private static func maxWakeWindowMinutes(ageMonths: Int) -> Int {
        switch max(ageMonths, 0) {
        case 0...1:
            return 60
        case 2:
            return 75
        case 3:
            return 90
        case 4:
            return 120
        case 5:
            return 135
        case 6:
            return 150
        case 7:
            return 165
        case 8...9:
            return 180
        case 10:
            return 195
        case 11:
            return 210
        case 12...13:
            return 240
        case 14:
            return 270
        case 15:
            return 270
        case 16:
            return 300
        case 17:
            return 300
        case 18:
            return 330
        case 19...20:
            return 360
        case 21...24:
            return 360
        case 25...30:
            return 390
        default:
            return 420
        }
    }

    private func stableCycleID(for draft: EasyCycleDraft) -> UUID {
        let starterID = draft.links.first(where: { $0.phase == .eat || $0.phase == .activity })?.id ?? draft.links.first?.id ?? "empty"
        return UUID.stableEasyCycleUUID(seed: starterID)
    }

    private func sortCycles() {
        cycles.sort { $0.startedAt > $1.startedAt }
    }

    private func loadCycles() {
        guard let data = defaults.data(forKey: key)
            ?? appGroupDefaults?.data(forKey: key),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
              let decoded = try? JSONDecoder().decode([EasyCycle].self, from: data) else {
            return
        }
        cycles = Array(
            decoded
                .prefix(BBBDataSafetyLimits.maxFeedingSessions)
                .sorted { $0.startedAt > $1.startedAt }
        )
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cycles) else { return }
        defaults.set(data, forKey: key)
        appGroupDefaults?.set(data, forKey: key)
        guard hasFinishedInitialization else { return }
        CareRecencyCoordinator.refreshFromSharedStorage(
            babyAgeMonths: BabyProfileStore.shared.currentProfile.ageMonths
        )
    }

    private func loadSourceRecords() {
        guard let data = defaults.data(forKey: sourceRecordsKey)
            ?? appGroupDefaults?.data(forKey: sourceRecordsKey),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
              let decoded = try? JSONDecoder().decode([EasyCycleSourceRecord].self, from: data) else {
            return
        }
        sourceRecords = decoded.prefix(BBBDataSafetyLimits.maxFeedingSessions).reduce(into: [:]) { result, record in
            // Older app-group snapshots can contain the same source record more than once.
            // Keep the first decoded value instead of trapping while rebuilding the index.
            if result[record.id] == nil {
                result[record.id] = record
            }
        }
        hasInitializedSourceRecords = true
    }

    private func persistSourceRecords() {
        guard let data = try? JSONEncoder().encode(Array(sourceRecords.values)) else { return }
        defaults.set(data, forKey: sourceRecordsKey)
        appGroupDefaults?.set(data, forKey: sourceRecordsKey)
    }

    private func loadPendingSplitNotice() {
        guard let data = defaults.data(forKey: pendingSplitNoticeKey)
            ?? appGroupDefaults?.data(forKey: pendingSplitNoticeKey),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
              let decoded = try? JSONDecoder().decode(EasyCycleSplitNotice.self, from: data) else {
            return
        }
        pendingSplitNotice = decoded
    }

    private func persistPendingSplitNotice() {
        guard let pendingSplitNotice else {
            defaults.removeObject(forKey: pendingSplitNoticeKey)
            appGroupDefaults?.removeObject(forKey: pendingSplitNoticeKey)
            return
        }
        guard let data = try? JSONEncoder().encode(pendingSplitNotice) else { return }
        defaults.set(data, forKey: pendingSplitNoticeKey)
        appGroupDefaults?.set(data, forKey: pendingSplitNoticeKey)
    }
}

private struct EasyCycleSourceRecord: Codable, Hashable {
    let type: EasyCycleLinkedRecordType
    let recordID: UUID
    let phase: EasyCyclePhase
    let startAt: Date
    let endAt: Date

    var id: String {
        "\(type.rawValue)-\(recordID.uuidString)"
    }

    var event: EasyCycleEvent {
        EasyCycleEvent(
            link: EasyCycleRecordLink(type: type, recordID: recordID, phase: phase),
            phase: phase,
            startAt: startAt,
            endAt: endAt
        )
    }
}

private struct EasyCycleMutationComponent {
    let existingIndices: [Int]
    let candidateIndices: [Int]
}

private struct EasyCycleEvent {
    let link: EasyCycleRecordLink
    let phase: EasyCyclePhase
    let startAt: Date
    let endAt: Date

    var sortPriority: Int {
        switch phase {
        case .eat: return 0
        case .activity: return 1
        case .sleep: return 2
        case .yearning: return 3
        }
    }

    static func isOrderedBefore(_ lhs: EasyCycleEvent, _ rhs: EasyCycleEvent) -> Bool {
        if lhs.startAt != rhs.startAt {
            return lhs.startAt < rhs.startAt
        }
        return lhs.sortPriority < rhs.sortPriority
    }
}

private struct EasyCycleDraft {
    var startedAt: Date
    var endedAt: Date?
    var activityStartedAt: Date?
    var activityEndedAt: Date?
    var links: [EasyCycleRecordLink] = []
    var updatedAt: Date
    var lastStarterAt: Date
    var lastEatAt: Date?

    init(startedAt: Date) {
        self.startedAt = startedAt
        self.updatedAt = startedAt
        self.lastStarterAt = startedAt
        self.lastEatAt = nil
    }

    var hasStarterRecord: Bool {
        links.contains { $0.phase == .eat || $0.phase == .activity }
    }

    var hasEat: Bool {
        links.contains { $0.phase == .eat }
    }

    var hasActivity: Bool {
        links.contains { $0.phase == .activity }
    }

    var hasSleep: Bool {
        links.contains { $0.phase == .sleep }
    }

    mutating func append(_ event: EasyCycleEvent) {
        if !links.contains(event.link) {
            links.append(event.link)
        }

        startedAt = min(startedAt, event.startAt)
        updatedAt = max(updatedAt, event.endAt)

        switch event.phase {
        case .eat:
            lastStarterAt = event.startAt
            lastEatAt = event.startAt
        case .activity:
            lastStarterAt = event.startAt
            activityStartedAt = activityStartedAt ?? event.startAt
            activityEndedAt = event.startAt
        case .sleep:
            endedAt = event.endAt
        case .yearning:
            break
        }
    }

    func closedForMissingSleep(before date: Date) -> EasyCycleDraft {
        var copy = self
        let fallbackEnd = max(lastStarterAt, date.addingTimeInterval(-1))
        copy.endedAt = copy.endedAt ?? fallbackEnd
        copy.updatedAt = max(copy.updatedAt, fallbackEnd)
        return copy
    }

    func finalizedCycle(id: UUID) -> EasyCycle? {
        guard hasStarterRecord else { return nil }

        let phase: EasyCyclePhase
        if hasSleep {
            phase = .yearning
        } else if hasActivity {
            phase = .sleep
        } else if hasEat {
            phase = .activity
        } else {
            phase = .eat
        }

        return EasyCycle(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            currentPhase: phase,
            status: hasSleep ? .readyToPublish : .active,
            activityStartedAt: activityStartedAt,
            activityEndedAt: activityEndedAt,
            linkedRecords: Array(Set(links)).sorted { $0.id < $1.id },
            updatedAt: updatedAt
        )
    }
}

private extension EasyCycle {
    func replacingIdentity(with id: UUID) -> EasyCycle {
        EasyCycle(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            currentPhase: currentPhase,
            status: status,
            activityStartedAt: activityStartedAt,
            activityEndedAt: activityEndedAt,
            note: note,
            linkedRecords: linkedRecords,
            publishedAt: publishedAt,
            updatedAt: updatedAt,
            supersededAt: supersededAt,
            supersedes: supersedes,
            supersededBy: supersededBy,
            mutationReason: mutationReason,
            pendingSplitReviewID: pendingSplitReviewID,
            groupingLockedAt: groupingLockedAt
        )
    }

    func preservingUserState(from existing: EasyCycle) -> EasyCycle {
        var cycle = self
        cycle.note = existing.note
        cycle.activityStartedAt = cycle.activityStartedAt ?? existing.activityStartedAt
        cycle.activityEndedAt = cycle.activityEndedAt ?? existing.activityEndedAt
        cycle.publishedAt = existing.publishedAt
        cycle.supersedes = existing.supersedes
        cycle.mutationReason = existing.mutationReason
        cycle.pendingSplitReviewID = existing.pendingSplitReviewID
        cycle.groupingLockedAt = existing.groupingLockedAt

        switch existing.status {
        case .published:
            cycle.status = .published
            cycle.currentPhase = .yearning
            cycle.endedAt = existing.endedAt ?? cycle.endedAt ?? existing.updatedAt
            cycle.publishedAt = existing.publishedAt ?? existing.updatedAt
        case .readyToPublish:
            cycle.status = .readyToPublish
            cycle.currentPhase = .yearning
            cycle.endedAt = existing.endedAt ?? cycle.endedAt
        case .active:
            if existing.currentPhase.progressionRank > cycle.currentPhase.progressionRank {
                cycle.currentPhase = existing.currentPhase
                cycle.endedAt = existing.endedAt ?? cycle.endedAt
            }
        }

        cycle.updatedAt = max(cycle.updatedAt, existing.updatedAt)
        return cycle
    }
}

private extension UUID {
    static func stableEasyCycleUUID(seed: String) -> UUID {
        let first = fnv1a64(seed: "easy-cycle-a|\(seed)")
        let second = fnv1a64(seed: "easy-cycle-b|\(seed)")
        var bytes = [UInt8]()

        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8((first >> UInt64(shift)) & 0xff))
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8((second >> UInt64(shift)) & 0xff))
        }

        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func fnv1a64(seed: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }
}

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)

        switch value.count {
        case 6:
            self.init(
                .sRGB,
                red: Double((number & 0xFF0000) >> 16) / 255,
                green: Double((number & 0x00FF00) >> 8) / 255,
                blue: Double(number & 0x0000FF) / 255,
                opacity: 1
            )
        case 8:
            self.init(
                .sRGB,
                red: Double((number & 0xFF000000) >> 24) / 255,
                green: Double((number & 0x00FF0000) >> 16) / 255,
                blue: Double((number & 0x0000FF00) >> 8) / 255,
                opacity: Double(number & 0x000000FF) / 255
            )
        default:
            self = .clear
        }
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignToken.cardCornerRadius)
                    .fill(DesignToken.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
            )
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    func primaryButtonStyle() -> some View {
        foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Capsule().fill(DesignToken.primaryGradient))
    }
}

// MARK: - Companion

enum CompanionRarity: String, Codable, CaseIterable, Hashable {
    case common
    case uncommon
    case rare
    case precious

    var title: String {
        switch self {
        case .common: return "普通".localized
        case .uncommon: return "少见".localized
        case .rare: return "稀有".localized
        case .precious: return "珍稀".localized
        }
    }

    var friendshipTarget: Int {
        switch self {
        case .common: return 36
        case .uncommon: return 72
        case .rare: return 108
        case .precious: return 180
        }
    }

}

struct CompanionFriendshipHearts: View {
    static let pointsPerHeart = 36

    let friendshipValue: Int
    let friendshipTarget: Int
    let size: CGFloat
    let fontWeight: Font.Weight
    var filledColor: Color = DesignToken.primary
    var emptyColor: Color = DesignToken.borderSubtle.opacity(0.72)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        friendshipValue: Int,
        friendshipTarget: Int,
        size: CGFloat,
        filledColor: Color = DesignToken.primary,
        emptyColor: Color = DesignToken.borderSubtle.opacity(0.72),
        fontWeight: Font.Weight = .heavy
    ) {
        self.friendshipValue = friendshipValue
        self.friendshipTarget = friendshipTarget
        self.size = size
        self.fontWeight = fontWeight
        self.filledColor = filledColor
        self.emptyColor = emptyColor
    }

    init(
        companion: BabyCompanion,
        friendshipValue: Int,
        isUnlocked: Bool,
        size: CGFloat,
        filledColor: Color = DesignToken.primary,
        emptyColor: Color = DesignToken.borderSubtle.opacity(0.72),
        fontWeight: Font.Weight = .heavy
    ) {
        self.init(
            friendshipValue: isUnlocked ? companion.friendshipTarget : friendshipValue,
            friendshipTarget: companion.friendshipTarget,
            size: size,
            filledColor: filledColor,
            emptyColor: emptyColor,
            fontWeight: fontWeight
        )
    }

    var body: some View {
        HStack(spacing: max(size * 0.18, 1.5)) {
            ForEach(0..<heartCount, id: \.self) { index in
                friendshipHeart(fill: fillAmount(for: index))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: displayedValue)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("友情值 \(displayedValue)/\(targetValue)，共 \(heartCount) 颗爱心")
    }

    private var targetValue: Int {
        max(friendshipTarget, Self.pointsPerHeart)
    }

    private var displayedValue: Int {
        min(max(friendshipValue, 0), targetValue)
    }

    private var heartCount: Int {
        max(Int(ceil(Double(targetValue) / Double(Self.pointsPerHeart))), 1)
    }

    private func fillAmount(for index: Int) -> Double {
        let pointsInHeart = displayedValue - index * Self.pointsPerHeart
        return min(max(Double(pointsInHeart) / Double(Self.pointsPerHeart), 0), 1)
    }

    private func friendshipHeart(fill: Double) -> some View {
        ZStack {
            Image(systemName: "heart")
                .foregroundStyle(emptyColor)

            Image(systemName: "heart.fill")
                .foregroundStyle(filledColor)
                .mask {
                    GeometryReader { proxy in
                        Rectangle()
                            .frame(width: proxy.size.width * fill)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
        }
        .font(.system(size: size, weight: fontWeight))
        .frame(width: size * 1.15, height: size * 1.15)
    }
}

struct BabyCompanion: Identifiable, Codable, Hashable {
    let id: String
    let chineseName: String
    let englishName: String
    let species: String
    let intro: String
    let emoji: String
    var rarity: CompanionRarity = .common
    var preferenceTags: [String] = []
    var specialConditionTags: [String] = []

    private static let fallback = BabyCompanion(
        id: "fallback",
        chineseName: "小伙伴",
        englishName: "Buddy",
        species: "陪伴动物",
        intro: "先陪你把今天过完。",
        emoji: "🐾"
    )

    var name: String { localizedName }
    var subtitle: String { "\(localizedName) · \(localizedSpecies)" }
    var description: String { localizedIntro }
    var localizedName: String {
        AppLocalization.language == .english ? englishName : chineseName
    }
    var localizedSpecies: String { species.localized }
    var localizedIntro: String { intro.localized }
    var localizedTemperamentLabel: String { temperamentLabel.localized }
    var localizedWorldDistribution: String { worldDistribution.localized }
    var portraitAssetName: String { "companion_\(englishName.lowercased())_portrait" }
    var catalogNumber: String {
        guard let index = Self.all.firstIndex(where: { $0.id == id }) else { return "C--" }
        return "C\(String(format: "%02d", index + 1))"
    }
    var temperamentLabel: String {
        switch id {
        case "bunny_lulu", "fawn_mimi", "cal", "samoyed_momo", "piggy", "alpaca_minta", "capybara_cappy", "panda_pandy", "beardie_beardy":
            return "稳定亲近"
        case "otter_tangtang", "fenny", "redpanda_youyou", "ferry", "raccoon_rocky", "seal_poro", "meerkat_meeko", "arcticfox_arki", "seaotter_otta", "macaque_maki", "kinkajou_kinka", "ringtail_ringo":
            return "节奏多变"
        case "koala_anan", "sloth_nono", "hedgehog_lili", "penguin_pino", "quokka_quoki", "chinchilla_chilla", "wombat_womby", "crane_crany", "tibetanfox_tibe", "manedwolf_maney", "moose_moosy":
            return "慢热观察"
        case "chipmunk_huohuo", "lemur_mika", "hamster_shushu", "sugar_glider_taffy", "sandcat_sandy", "flyingsquirrel_glidy", "pallascat_pally", "tapir_tapi":
            return "高敏感"
        default:
            return "温柔陪伴"
        }
    }
    var temperamentStyle: (tint: Color, text: Color) {
        switch temperamentLabel {
        case "稳定亲近":
            return (DesignToken.easyYearningSoft, DesignToken.easyYearningText)
        case "节奏多变":
            return (DesignToken.warningSoft, DesignToken.warningText)
        case "慢热观察":
            return (DesignToken.easySleepSoft, DesignToken.easySleepText)
        case "高敏感":
            return (DesignToken.easyActivitySoft, DesignToken.easyActivityText)
        default:
            return (DesignToken.primarySoft, DesignToken.primary)
        }
    }
    var worldDistribution: String {
        switch id {
        case "bunny_lulu": return "荷兰培育，现随宠物与展示饲养分布于多地。"
        case "fawn_mimi": return "原产东亚，见于中国、日本、朝鲜半岛与俄罗斯远东等地。"
        case "cal": return "欧洲培育的展示鸭品种，随观赏饲养分布。"
        case "samoyed_momo": return "源自西伯利亚萨摩耶人地区，现作为家犬在全球多地饲养。"
        case "otter_tangtang": return "野外原产南亚和东南亚湿地、河流、红树林等生境。"
        case "fenny": return "野外分布于撒哈拉及北非干旱荒漠。"
        case "redpanda_youyou": return "野外局限于喜马拉雅东段和中国西南山地。"
        case "koala_anan": return "野外分布于澳大利亚东部和东南部桉树林。"
        case "sloth_nono": return "野外分布于中美洲至南美洲部分热带森林。"
        case "chipmunk_huohuo": return "野外广布于北亚和东北亚森林。"
        case "piggy": return "家养小型猪品系，主要见于实验、宠物和保育饲养。"
        case "ferry": return "家养雪貂品系，现欧美及多地作为宠物饲养。"
        case "alpaca_minta": return "南美安第斯家养驼类，现全球牧场饲养。"
        case "raccoon_rocky": return "原产北美，现北美广泛分布，并被引入欧洲、日本等地。"
        case "seal_poro": return "广布北半球温带和亚寒带沿海水域。"
        case "hedgehog_lili": return "刺猬类分布于欧洲、亚洲、非洲。"
        case "penguin_pino": return "以小企鹅为参考，原产澳大利亚和新西兰沿海。"
        case "lemur_mika": return "以环尾狐猴为参考，野外仅见于马达加斯加南部和西南部。"
        case "hamster_shushu": return "以叙利亚仓鼠为参考，野外原产叙利亚、土耳其一带。"
        case "sugar_glider_taffy": return "原产澳大利亚、新几内亚及周边岛屿。"
        case "capybara_cappy": return "原产南美洲，主要分布于湿地、河流和沼泽区域。"
        case "quokka_quoki": return "野外分布于澳大利亚西南部少数岛屿和沿海灌丛。"
        case "meerkat_meeko": return "原产非洲南部干旱草原和沙漠边缘。"
        case "sandcat_sandy": return "原产北非和中东的沙漠地带。"
        case "arcticfox_arki": return "原产北极圈附近苔原地带。"
        case "seaotter_otta": return "原产北太平洋沿岸海域。"
        case "flyingsquirrel_glidy": return "以亚洲大型鼯鼠为参考，主要生活在森林树冠层。"
        case "chinchilla_chilla": return "野外原产南美洲安第斯山脉高海拔地区。"
        case "pallascat_pally": return "原产中亚高原和干旱草原、岩石地带。"
        case "wombat_womby": return "原产澳大利亚东南部和塔斯马尼亚。"
        case "panda_pandy": return "原产中国西南山区竹林。"
        case "crane_crany": return "原产东亚湿地，迁徙经过东北亚多地。"
        case "macaque_maki": return "猕猴广泛分布于亚洲多地，常见于山地、林缘与河谷环境。"
        case "beardie_beardy": return "原产澳大利亚中部和东部干旱林地。"
        case "tibetanfox_tibe": return "原产青藏高原及周边高寒草甸、荒漠草原地带。"
        case "manedwolf_maney": return "原产南美洲草原和灌丛地带。"
        case "kinkajou_kinka": return "原产中美洲和南美洲热带雨林。"
        case "ringtail_ringo": return "原产北美西南部干旱林地和岩石区域。"
        case "tapir_tapi": return "以低地貘为参考，原产南美洲森林和湿地。"
        case "moose_moosy": return "分布于北半球寒温带森林和湿地。"
        default: return "更多分布资料整理中。"
        }
    }
    var friendshipTarget: Int { rarity.friendshipTarget }
    var lockedMaskAssetName: String? {
        "companion_\(englishName.lowercased())_locked_mask"
    }

    static let all: [BabyCompanion] = [
        .init(id: "bunny_lulu", chineseName: "洛噗", englishName: "Loppy", species: "荷兰垂耳兔宝宝", intro: "稳定亲近、反应柔和，是容易被轻轻引导的小甜心。", emoji: "🐰", rarity: .common),
        .init(id: "fawn_mimi", chineseName: "西咔", englishName: "Sika", species: "梅花鹿宝宝", intro: "安静细腻、喜欢熟悉节奏，需要被温柔守护。", emoji: "🦌", rarity: .common),
        .init(id: "cal", chineseName: "柯噜", englishName: "Cal", species: "柯尔鸭宝宝", intro: "圆滚滚、步伐慢半拍，擅长把普通日常变得可爱。", emoji: "🦆", rarity: .uncommon),
        .init(id: "samoyed_momo", chineseName: "摩耶", englishName: "Moye", species: "萨摩耶宝宝", intro: "亲和稳定、适应力强，像随时给人安心的陪伴。", emoji: "🐶", rarity: .common),
        .init(id: "otter_tangtang", chineseName: "欧缇", englishName: "Ottie", species: "亚洲小爪水獭宝宝", intro: "状态丰富、节奏多变，需要弹性和耐心配合。", emoji: "🦦", rarity: .rare),
        .init(id: "fenny", chineseName: "芬灵", englishName: "Fenny", species: "耳廓狐宝宝", intro: "敏锐聪明、先观察再靠近，对环境里的细节特别有感觉。", emoji: "🦊", rarity: .uncommon),
        .init(id: "redpanda_youyou", chineseName: "瑞迪", englishName: "Reddy", species: "小熊猫宝宝", intro: "柔软但有主见，喜欢按自己的方式慢慢进入状态。", emoji: "🐾", rarity: .precious),
        .init(id: "koala_anan", chineseName: "阿考", englishName: "Ako", species: "昆士兰考拉宝宝", intro: "慢热谨慎、观察力强，安全感足够后会认真靠近。", emoji: "🐨", rarity: .uncommon),
        .init(id: "sloth_nono", chineseName: "霍菲", englishName: "Hoffy", species: "霍氏树懒宝宝", intro: "慢节奏、低刺激偏好，需要更从容的过渡时间。", emoji: "🌿", rarity: .common),
        .init(id: "chipmunk_huohuo", chineseName: "奇比", englishName: "Chippy", species: "西伯利亚花栗鼠宝宝", intro: "感受强烈、反应很快，需要更多安抚和提前预告。", emoji: "✨", rarity: .common),
        .init(id: "piggy", chineseName: "尤卡", englishName: "Yuca", species: "尤卡坦迷你猪宝宝", intro: "爱睡觉也爱贴贴，是小木屋里最松弛的暖心伙伴。", emoji: "🐷", rarity: .uncommon),
        .init(id: "ferry", chineseName: "雪溜", englishName: "Ferry", species: "安格鲁貂宝宝", intro: "软绵灵活、好奇心强，喜欢在日常缝隙里发现小惊喜。", emoji: "🦦", rarity: .uncommon),
        .init(id: "alpaca_minta", chineseName: "绵塔", englishName: "Minta", species: "羊驼宝宝", intro: "温顺松弛、节奏稳定，是会把紧张气氛慢慢变软的小伙伴。", emoji: "🦙", rarity: .common),
        .init(id: "raccoon_rocky", chineseName: "洛奇", englishName: "Rocky", species: "浣熊宝宝", intro: "聪明好奇、很有小主意，是喜欢在日常角落里发现新鲜事的小侦探。", emoji: "🦝", rarity: .common),
        .init(id: "seal_poro", chineseName: "泡露", englishName: "Poro", species: "小海豹宝宝", intro: "亲近爱撒娇、状态切换丰富，是今天想贴贴、明天想探索的小浪花。", emoji: "🦭", rarity: .uncommon),
        .init(id: "hedgehog_lili", chineseName: "栗栗", englishName: "Lili", species: "小刺猬宝宝", intro: "谨慎慢热、内心柔软，是熟悉之后才会悄悄靠近的小暖球。", emoji: "🦔", rarity: .uncommon),
        .init(id: "penguin_pino", chineseName: "皮诺", englishName: "Pino", species: "小企鹅宝宝", intro: "慢热认真、需要安全感，是先站稳再一步步靠近世界的小朋友。", emoji: "🐧", rarity: .uncommon),
        .init(id: "lemur_mika", chineseName: "米卡", englishName: "Mika", species: "小狐猴宝宝", intro: "眼神敏锐、反应很快，是很容易感受到环境变化的小观察家。", emoji: "🐾", rarity: .precious),
        .init(id: "hamster_shushu", chineseName: "咻咻", englishName: "Shushu", species: "小仓鼠宝宝", intro: "感受细腻、动作很快，是紧张时想躲一躲、安心后会主动贴近的小伙伴。", emoji: "🐹", rarity: .precious),
        .init(id: "sugar_glider_taffy", chineseName: "糖飞", englishName: "Taffy", species: "小蜜袋鼯宝宝", intro: "黏人敏感、很需要陪伴，是分开时会想念、靠近时会放松的小夜星。", emoji: "🐾", rarity: .common),
        .init(id: "capybara_cappy", chineseName: "卡皮", englishName: "Cappy", species: "水豚宝宝", intro: "佛系松弛、节奏很慢，是任何时候都不会着急的温柔大个子。", emoji: "🐾", rarity: .common),
        .init(id: "quokka_quoki", chineseName: "阔奇", englishName: "Quoki", species: "短尾矮袋鼠宝宝", intro: "天然笑脸、慢热谨慎，是笑着观察很久才愿意靠近的小太阳。", emoji: "🐾", rarity: .precious),
        .init(id: "meerkat_meeko", chineseName: "米寇", englishName: "Meeko", species: "狐獴宝宝", intro: "好奇勇敢、团队意识强，是探头看看世界又会回头确认同伴的小哨兵。", emoji: "🐾", rarity: .common),
        .init(id: "sandcat_sandy", chineseName: "砂迪", englishName: "Sandy", species: "沙丘猫宝宝", intro: "耳朵很大、感受力很强，是安静环境里才能放松的细腻小耳朵。", emoji: "🐾", rarity: .rare),
        .init(id: "arcticfox_arki", chineseName: "阿奇", englishName: "Arki", species: "北极狐宝宝", intro: "会随环境慢慢调整状态，是适应力强又有自己节奏的雪地小精灵。", emoji: "🐾", rarity: .uncommon),
        .init(id: "seaotter_otta", chineseName: "奥塔", englishName: "Otta", species: "海獭宝宝", intro: "活泼爱互动、动手能力强，是喜欢用小手探索世界的水中开心果。", emoji: "🐾", rarity: .uncommon),
        .init(id: "flyingsquirrel_glidy", chineseName: "格莱", englishName: "Glidy", species: "大鼯鼠宝宝", intro: "大眼睛、动作快，是容易受惊但滑翔起来特别优雅的夜空小星星。", emoji: "🐾", rarity: .uncommon),
        .init(id: "chinchilla_chilla", chineseName: "奇拉", englishName: "Chilla", species: "长毛龙猫宝宝", intro: "毛茸茸、胆子小，是需要很安静才能放松下来的蓬松小团子。", emoji: "🐾", rarity: .precious),
        .init(id: "pallascat_pally", chineseName: "帕利", englishName: "Pally", species: "兔狲宝宝", intro: "天生表情酷酷的，但内心很敏感，是需要慢慢靠近的小方脸。", emoji: "🐾", rarity: .rare),
        .init(id: "wombat_womby", chineseName: "旺比", englishName: "Womby", species: "袋熊宝宝", intro: "方方正正、慢吞吞，是踏踏实实走每一步的澳洲小土墩。", emoji: "🐾", rarity: .common),
        .init(id: "panda_pandy", chineseName: "潘迪", englishName: "Pandy", species: "大熊猫宝宝", intro: "圆滚滚、慢吞吞，是让紧张日常慢慢软下来的黑白小团子。", emoji: "🐾", rarity: .precious),
        .init(id: "crane_crany", chineseName: "克瑞", englishName: "Crany", species: "丹顶鹤宝宝", intro: "优雅安静、节奏很慢，是先远远看着再慢慢走近的白色小伙伴。", emoji: "🐾", rarity: .precious),
        .init(id: "macaque_maki", chineseName: "玛奇", englishName: "Maki", species: "猕猴宝宝", intro: "红脸蛋、好奇心强，是喜欢观察别人也有自己主意的社交小暖猴。", emoji: "🐾", rarity: .common),
        .init(id: "beardie_beardy", chineseName: "比迪", englishName: "Beardy", species: "中部鬃狮蜥宝宝", intro: "看起来有点酷但其实很温和，是喜欢安静晒太阳的淡定小伙伴。", emoji: "🐾", rarity: .common),
        .init(id: "tibetanfox_tibe", chineseName: "提布", englishName: "Tibe", species: "藏狐宝宝", intro: "表情淡定、慢热观察，是确认安全后才把柔软一面露出来的高原小伙伴。", emoji: "🐾", rarity: .uncommon),
        .init(id: "manedwolf_maney", chineseName: "曼耶", englishName: "Maney", species: "鬃狼宝宝", intro: "步子很轻、距离感强，是确认安全后才慢慢靠近的安静小影子。", emoji: "🐾", rarity: .rare),
        .init(id: "kinkajou_kinka", chineseName: "金卡", englishName: "Kinka", species: "蜜熊宝宝", intro: "夜晚才活跃、节奏特别，是安静夜色里慢慢探索的甜蜜小伙伴。", emoji: "🐾", rarity: .common),
        .init(id: "ringtail_ringo", chineseName: "林果", englishName: "Ringo", species: "环尾猫宝宝", intro: "尾巴一圈一圈、好奇又灵巧，是喜欢在角落里发现秘密的小伙伴。", emoji: "🐾", rarity: .common),
        .init(id: "tapir_tapi", chineseName: "塔皮", englishName: "Tapi", species: "小貘宝宝", intro: "鼻子软软、感受细腻，是先闻闻世界再决定靠近的小森林朋友。", emoji: "🐾", rarity: .rare),
        .init(id: "moose_moosy", chineseName: "穆西", englishName: "Moosy", species: "小驼鹿宝宝", intro: "大耳朵、慢半拍，是需要宽宽空间和慢慢节奏的温和大朋友。", emoji: "🐾", rarity: .common)
    ]

    static let defaultUnlockedIDs: Set<String> = ["piggy", "fenny", "ferry", "cal"]
    static let previewLockedIDs: Set<String> = []

    static func companion(for id: String) -> BabyCompanion {
        all.first(where: { $0.id == id }) ?? all.first ?? fallback
    }

    static func canonicalID(_ id: String) -> String {
        id
    }

    static func unlockedIDs(
        selectedID: String,
        temperamentAnimalID: String?,
        includingLocalDebugUnlocks: Bool = true
    ) -> Set<String> {
        if includingLocalDebugUnlocks, AppVariant.unlocksAllBuddiesForLocalRun {
            return Set(all.map { canonicalID($0.id) })
        }

        var ids = Set(defaultUnlockedIDs.map(canonicalID))
        ids.insert(canonicalID(selectedID))

        if let temperamentAnimalID {
            ids.insert(canonicalID(temperamentAnimalID))
        }

        ids.subtract(previewLockedIDs.map(canonicalID))
        return ids
    }

    func isUnlocked(selectedID: String, temperamentAnimalID: String?) -> Bool {
        Self.unlockedIDs(selectedID: selectedID, temperamentAnimalID: temperamentAnimalID)
            .contains(Self.canonicalID(id))
    }

    static func companionPageAnimals(selectedID: String, temperamentAnimalID: String?, recruitedIDs: Set<String> = []) -> [CompanionAnimalPresence] {
        all.compactMap { companion in
            let isUnlocked = companion.isUnlocked(selectedID: selectedID, temperamentAnimalID: temperamentAnimalID)
                || recruitedIDs.contains(companion.id)
            return isUnlocked ? CompanionAnimalPresence(companion: companion) : nil
        }
    }
}

struct CompanionAnimalPresence: Identifiable, Hashable {
    let companion: BabyCompanion

    var id: String { companion.id }
}

@MainActor
final class CompanionStore: ObservableObject {
    @Published var selectedID: String {
        didSet {
            UserDefaults.standard.set(selectedID, forKey: "selected_companion_id")
            FamilyCloudStore.shared.scheduleUpload(reason: "companion")
        }
    }

    init() {
        self.selectedID = UserDefaults.standard.string(forKey: "selected_companion_id") ?? "cal"
    }

    var selected: BabyCompanion {
        BabyCompanion.companion(for: selectedID)
    }

    func importSelectedID(_ id: String) {
        guard BabyCompanion.all.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }
}

struct YesterdayReport: Identifiable, Codable, Equatable {
    var id: String { reportKey }
    var reportKey: String
    var date: Date
    var dateText: String
    var feedingCount: Int
    var bottleAmount: Int
    var breastMinutes: Int
    var solidAmount: Int
    var diaperCount: Int
    var sleepMinutes: Int
    var feedingHours: Set<Int>
    var diaperHours: Set<Int>
    var sleepHours: Set<Int>
    var rhythmText: String
    var analysisText: String
    var earnedBBBucks: Int
    var visitorCompanionID: String
    var visitorCompanionIDs: [String]
    var fedCompanionID: String?
    var fedBBBucks: Int
    var feedings: [YesterdayBuddyFeeding]
    var createdAt: Date

    var visitorIDs: [String] {
        let ids = visitorCompanionIDs.isEmpty ? [visitorCompanionID] : visitorCompanionIDs
        return Array(NSOrderedSet(array: ids.filter { !$0.isEmpty }).compactMap { $0 as? String })
    }

    init(
        reportKey: String,
        date: Date,
        dateText: String,
        feedingCount: Int,
        bottleAmount: Int,
        breastMinutes: Int,
        solidAmount: Int,
        diaperCount: Int,
        sleepMinutes: Int,
        feedingHours: Set<Int>,
        diaperHours: Set<Int>,
        sleepHours: Set<Int>,
        rhythmText: String,
        analysisText: String,
        earnedBBBucks: Int,
        visitorCompanionID: String,
        visitorCompanionIDs: [String]? = nil,
        fedCompanionID: String? = nil,
        fedBBBucks: Int = 0,
        feedings: [YesterdayBuddyFeeding]? = nil,
        createdAt: Date
    ) {
        self.reportKey = reportKey
        self.date = date
        self.dateText = dateText
        self.feedingCount = feedingCount
        self.bottleAmount = bottleAmount
        self.breastMinutes = breastMinutes
        self.solidAmount = solidAmount
        self.diaperCount = diaperCount
        self.sleepMinutes = sleepMinutes
        self.feedingHours = feedingHours
        self.diaperHours = diaperHours
        self.sleepHours = sleepHours
        self.rhythmText = rhythmText
        self.analysisText = analysisText
        self.earnedBBBucks = earnedBBBucks
        self.visitorCompanionID = visitorCompanionID
        let visitors = visitorCompanionIDs ?? [visitorCompanionID]
        self.visitorCompanionIDs = visitors.filter { !$0.isEmpty }
        self.fedCompanionID = fedCompanionID
        self.fedBBBucks = fedBBBucks
        if let feedings {
            self.feedings = feedings
        } else if let fedCompanionID, fedBBBucks > 0 {
            self.feedings = [
                YesterdayBuddyFeeding(
                    companionID: fedCompanionID,
                    servings: fedBBBucks,
                    spentBBBucks: fedBBBucks,
                    bonusServings: 0
                )
            ]
        } else {
            self.feedings = []
        }
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case reportKey
        case date
        case dateText
        case feedingCount
        case bottleAmount
        case breastMinutes
        case solidAmount
        case diaperCount
        case sleepMinutes
        case feedingHours
        case diaperHours
        case sleepHours
        case rhythmText
        case analysisText
        case earnedBBBucks
        case visitorCompanionID
        case visitorCompanionIDs
        case fedCompanionID
        case fedBBBucks
        case feedings
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reportKey = try container.decode(String.self, forKey: .reportKey)
        date = try container.decode(Date.self, forKey: .date)
        dateText = try container.decode(String.self, forKey: .dateText)
        feedingCount = try container.decode(Int.self, forKey: .feedingCount)
        bottleAmount = try container.decode(Int.self, forKey: .bottleAmount)
        breastMinutes = try container.decode(Int.self, forKey: .breastMinutes)
        solidAmount = try container.decode(Int.self, forKey: .solidAmount)
        diaperCount = try container.decode(Int.self, forKey: .diaperCount)
        sleepMinutes = try container.decode(Int.self, forKey: .sleepMinutes)
        feedingHours = try container.decode(Set<Int>.self, forKey: .feedingHours)
        diaperHours = try container.decode(Set<Int>.self, forKey: .diaperHours)
        sleepHours = try container.decode(Set<Int>.self, forKey: .sleepHours)
        rhythmText = try container.decode(String.self, forKey: .rhythmText)
        analysisText = try container.decode(String.self, forKey: .analysisText)
        earnedBBBucks = try container.decode(Int.self, forKey: .earnedBBBucks)
        visitorCompanionID = try container.decodeIfPresent(String.self, forKey: .visitorCompanionID) ?? ""
        visitorCompanionIDs = (try container.decodeIfPresent([String].self, forKey: .visitorCompanionIDs) ?? [])
            .filter { !$0.isEmpty }
        fedCompanionID = try container.decodeIfPresent(String.self, forKey: .fedCompanionID)
        fedBBBucks = try container.decodeIfPresent(Int.self, forKey: .fedBBBucks) ?? 0
        if let decodedFeedings = try container.decodeIfPresent([YesterdayBuddyFeeding].self, forKey: .feedings) {
            feedings = decodedFeedings
        } else if let fedCompanionID, fedBBBucks > 0 {
            feedings = [
                YesterdayBuddyFeeding(
                    companionID: fedCompanionID,
                    servings: fedBBBucks,
                    spentBBBucks: fedBBBucks,
                    bonusServings: 0
                )
            ]
        } else {
            feedings = []
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct YesterdayBuddyFeeding: Identifiable, Codable, Equatable {
    var id: String { companionID }
    var companionID: String
    var servings: Int
    var spentBBBucks: Int
    var bonusServings: Int
}

enum DailyTaskID: String, CaseIterable, Codable, Hashable, Identifiable {
    case easyCycle
    case viewReport
    case dailyPhoto
    case subjectiveState

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easyCycle: return "完成 EASY 循环"
        case .viewReport: return "查看 BBBrief"
        case .dailyPhoto: return "每日一拍"
        case .subjectiveState: return "记录 Y 状态"
        }
    }

    var rewardAmount: Int {
        switch self {
        case .easyCycle: return 3
        case .viewReport, .dailyPhoto, .subjectiveState: return 1
        }
    }

    var targetCount: Int {
        self == .easyCycle ? 3 : 1
    }
}

struct DailyTaskProgress: Identifiable, Equatable {
    let taskID: DailyTaskID
    let completedCount: Int
    let targetCount: Int
    let rewardAmount: Int
    let plusRewardAmount: Int

    var id: DailyTaskID { taskID }
    var isCompleted: Bool { completedCount >= targetCount }
}

enum BBBuckTransactionSource: String, Codable, Hashable {
    case easyCycle
    case dailyTask
    case achievement
    case buddyInvitation
    case historicalImport
    case migration
}

private enum BBBuckLedgerLimits {
    static let maxTransactions = BBBDataSafetyLimits.maxRecruitmentTransactions
    static let maxAmountMagnitude = 1_000_000
    static let maxBalanceMagnitude = 10_000_000

    static func checkedAmount(baseAmount: Int, plusBonus: Int) -> Int? {
        guard (-maxAmountMagnitude...maxAmountMagnitude).contains(baseAmount),
              (-maxAmountMagnitude...maxAmountMagnitude).contains(plusBonus) else {
            return nil
        }
        let (amount, overflow) = baseAmount.addingReportingOverflow(plusBonus)
        guard !overflow, (-maxAmountMagnitude...maxAmountMagnitude).contains(amount) else {
            return nil
        }
        return amount
    }

    static func add(_ lhs: Int, _ rhs: Int) -> Int? {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow, (-maxBalanceMagnitude...maxBalanceMagnitude).contains(value) else {
            return nil
        }
        return value
    }

    static func subtract(_ lhs: Int, _ rhs: Int) -> Int? {
        let (value, overflow) = lhs.subtractingReportingOverflow(rhs)
        guard !overflow, (-maxBalanceMagnitude...maxBalanceMagnitude).contains(value) else {
            return nil
        }
        return value
    }

    static func clampBalance(_ value: Int) -> Int {
        min(max(value, -maxBalanceMagnitude), maxBalanceMagnitude)
    }
}

struct BBBuckTransaction: Identifiable, Codable, Hashable {
    let id: String
    let source: BBBuckTransactionSource
    let cycleID: UUID?
    let careDayID: String
    let baseAmount: Int
    let plusBonus: Int
    let createdAt: Date
    var taskID: DailyTaskID? = nil
    var referenceID: String? = nil
    var companionID: String? = nil

    var checkedAmount: Int? {
        BBBuckLedgerLimits.checkedAmount(baseAmount: baseAmount, plusBonus: plusBonus)
    }

    var amount: Int { checkedAmount ?? 0 }
}

enum BBBuckAwardStatus: Equatable {
    case awarded
    case duplicate
    case dailyLimitReached
    case historical
}

struct BBBuckAwardResult: Equatable {
    let status: BBBuckAwardStatus
    let baseAmount: Int
    let plusBonus: Int
    let rewardedCycleCount: Int

    var amount: Int {
        BBBuckLedgerLimits.checkedAmount(baseAmount: baseAmount, plusBonus: plusBonus) ?? 0
    }
}

struct HistoricalImportSettlement: Codable, Equatable {
    var awardedAmount: Int
    var importFingerprints: Set<String>

    static let empty = HistoricalImportSettlement(awardedAmount: 0, importFingerprints: [])
}

struct CompanionRecruitmentSnapshot: Codable, Equatable {
    var bbBucks: Int
    var balanceAnchor: Int?
    var friendshipValues: [String: Int]
    var recruitedIDs: Set<String>
    var transactions: [BBBuckTransaction]
    var historicalImportSettlement: HistoricalImportSettlement
}

enum CompanionRecruitmentLedgerMerger {
    static func sanitizedSnapshot(_ snapshot: CompanionRecruitmentSnapshot) -> CompanionRecruitmentSnapshot {
        let friendshipValues = Dictionary(
            snapshot.friendshipValues
                .filter { !$0.key.isEmpty && (0...100_000).contains($0.value) }
                .prefix(256)
                .map { ($0.key, $0.value) },
            uniquingKeysWith: { current, _ in current }
        )
        let recruitedIDs = Set(
            snapshot.recruitedIDs
                .filter { !$0.isEmpty }
                .prefix(256)
                .map(BabyCompanion.canonicalID(_:))
        )
        let settlement = HistoricalImportSettlement(
            awardedAmount: min(max(snapshot.historicalImportSettlement.awardedAmount, 0), 270),
            importFingerprints: Set(
                snapshot.historicalImportSettlement.importFingerprints
                    .filter { !$0.isEmpty }
                    .prefix(256)
            )
        )
        return CompanionRecruitmentSnapshot(
            bbBucks: max(BBBuckLedgerLimits.clampBalance(snapshot.bbBucks), 0),
            balanceAnchor: snapshot.balanceAnchor.map(BBBuckLedgerLimits.clampBalance),
            friendshipValues: friendshipValues,
            recruitedIDs: recruitedIDs,
            transactions: sanitizedTransactions(snapshot.transactions),
            historicalImportSettlement: settlement
        )
    }

    static func sanitizedTransactions(_ transactions: [BBBuckTransaction]) -> [BBBuckTransaction] {
        var byID: [String: BBBuckTransaction] = [:]
        for transaction in transactions {
            guard !transaction.id.isEmpty,
                  transaction.checkedAmount != nil,
                  transaction.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  byID[transaction.id] == nil else {
                continue
            }
            byID[transaction.id] = transaction
            if byID.count >= BBBuckLedgerLimits.maxTransactions { break }
        }
        return byID.values.sorted {
            if $0.createdAt == $1.createdAt { return $0.id < $1.id }
            return $0.createdAt < $1.createdAt
        }
    }

    static func merge(
        local: CompanionRecruitmentSnapshot,
        remote: CompanionRecruitmentSnapshot,
        preferRemoteFields _: Bool
    ) -> CompanionRecruitmentSnapshot {
        let local = sanitizedSnapshot(local)
        let remote = sanitizedSnapshot(remote)
        var transactionByID: [String: BBBuckTransaction] = [:]
        for transaction in local.transactions where transactionByID[transaction.id] == nil {
            transactionByID[transaction.id] = transaction
        }
        for transaction in remote.transactions {
            transactionByID[transaction.id] = transactionByID[transaction.id] ?? transaction
        }

        let balanceAnchor = max(balanceAnchor(for: local), balanceAnchor(for: remote))
        var rebuiltBalance = balanceAnchor
        var validTransactions: [BBBuckTransaction] = []
        for transaction in transactionByID.values.sorted(by: transactionOrder) {
            guard let nextBalance = BBBuckLedgerLimits.add(rebuiltBalance, transaction.amount),
                  transaction.amount >= 0 || nextBalance >= 0,
                  validTransactions.count < BBBuckLedgerLimits.maxTransactions else {
                continue
            }
            validTransactions.append(transaction)
            rebuiltBalance = nextBalance
        }

        let allCompanionIDs = Set(local.friendshipValues.keys)
            .union(remote.friendshipValues.keys)
            .union(invitationCompanionIDs(in: local.transactions))
            .union(invitationCompanionIDs(in: remote.transactions))
        var mergedFriendshipValues: [String: Int] = [:]
        for companionID in allCompanionIDs {
            let canonicalID = BabyCompanion.canonicalID(companionID)
            let localValue = local.friendshipValues[companionID] ?? local.friendshipValues[canonicalID] ?? 0
            let remoteValue = remote.friendshipValues[companionID] ?? remote.friendshipValues[canonicalID] ?? 0
            let localAnchor = max(
                BBBuckLedgerLimits.subtract(
                    localValue,
                    invitationAmount(for: canonicalID, in: local.transactions)
                ) ?? 0,
                0
            )
            let remoteAnchor = max(
                BBBuckLedgerLimits.subtract(
                    remoteValue,
                    invitationAmount(for: canonicalID, in: remote.transactions)
                ) ?? 0,
                0
            )
            let rebuiltValue = BBBuckLedgerLimits.add(
                max(localAnchor, remoteAnchor),
                invitationAmount(for: canonicalID, in: validTransactions)
            ) ?? max(localAnchor, remoteAnchor)
            let target = BabyCompanion.companion(for: canonicalID).friendshipTarget
            mergedFriendshipValues[canonicalID] = min(max(rebuiltValue, 0), target)
        }

        let invitationIDs = invitationCompanionIDs(in: local.transactions)
            .union(invitationCompanionIDs(in: remote.transactions))
        var recruitedIDs = local.recruitedIDs.union(remote.recruitedIDs)
            .filter { !invitationIDs.contains(BabyCompanion.canonicalID($0)) }
        for (companionID, value) in mergedFriendshipValues
        where value >= BabyCompanion.companion(for: companionID).friendshipTarget {
            recruitedIDs.insert(companionID)
        }

        return CompanionRecruitmentSnapshot(
            bbBucks: max(rebuiltBalance, 0),
            balanceAnchor: balanceAnchor,
            friendshipValues: mergedFriendshipValues,
            recruitedIDs: Set(recruitedIDs.map(BabyCompanion.canonicalID(_:))),
            transactions: validTransactions,
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

    private static func balanceAnchor(for snapshot: CompanionRecruitmentSnapshot) -> Int {
        if let balanceAnchor = snapshot.balanceAnchor {
            return BBBuckLedgerLimits.clampBalance(balanceAnchor)
        }
        let total = snapshot.transactions.reduce(0) { current, transaction in
            BBBuckLedgerLimits.add(current, transaction.amount) ?? current
        }
        return BBBuckLedgerLimits.subtract(snapshot.bbBucks, total) ?? 0
    }

    private static func transactionOrder(_ lhs: BBBuckTransaction, _ rhs: BBBuckTransaction) -> Bool {
        if lhs.createdAt == rhs.createdAt { return lhs.id < rhs.id }
        return lhs.createdAt < rhs.createdAt
    }

    private static func invitationCompanionIDs(in transactions: [BBBuckTransaction]) -> Set<String> {
        Set(transactions.compactMap { transaction in
            guard transaction.source == .buddyInvitation,
                  let companionID = transaction.companionID ?? transaction.referenceID else { return nil }
            return BabyCompanion.canonicalID(companionID)
        })
    }

    private static func invitationAmount(for companionID: String, in transactions: [BBBuckTransaction]) -> Int {
        transactions.reduce(0) { total, transaction in
            guard transaction.source == .buddyInvitation,
                  BabyCompanion.canonicalID(transaction.companionID ?? transaction.referenceID ?? "") == companionID else {
                return total
            }
            return BBBuckLedgerLimits.add(total, max(-transaction.amount, 0)) ?? total
        }
    }
}

enum SceneUnlockRule: Codable, Hashable {
    case free
    case milestone(String)
    case achievementCount(Int)
    case plusVariant(baseSceneID: String)
    case event(String)
}

struct SceneEntitlement: Identifiable, Codable, Hashable {
    let id: String
    let sceneID: String
    let awardedAt: Date
    let sourceAchievementID: UUID?
}

@MainActor
final class CompanionRecruitmentStore: ObservableObject {
    static let shared = CompanionRecruitmentStore()
    static let currencyName = "BB Bucks"
    static let dailyEarnLimit = 12
    static let plusDailyEarnLimit = 15
    static let dailyRewardedCycleLimit = 3
    static let baseCycleReward = 3
    static let plusCycleBonus = 1
    static let historicalImportLifetimeLimit = 270

    static func currencyText(_ amount: Int) -> String {
        amount == 1 ? "1 BB Buck" : "\(amount) BB Bucks"
    }

    @Published private(set) var bbBucks: Int = 0 {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var friendshipValues: [String: Int] = [:] {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var recruitedIDs: Set<String> = [] {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var reports: [YesterdayReport] = [] {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var transactions: [BBBuckTransaction] = [] {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var historicalImportSettlement: HistoricalImportSettlement = .empty {
        didSet { persistIfLoaded() }
    }

    private let bbBucksKey = "companion_recruitment_bb_bucks_v1"
    private let friendshipKey = "companion_recruitment_friendship_v1"
    private let friendshipValuesKey = "companion_recruitment_friendship_values_v2"
    private let recruitedKey = "companion_recruitment_recruited_ids_v1"
    private let reportsKey = "companion_recruitment_yesterday_reports_v1"
    private let dailyEarningsKey = "companion_recruitment_daily_earnings_v1"
    private let awardedEasyCycleIDsKey = "companion_recruitment_awarded_easy_cycle_ids_v1"
    private let transactionsKey = "companion_recruitment_transactions_v2"
    private let historicalImportKey = "companion_recruitment_historical_import_v2"
    private let homeTimeZoneKey = "companion_recruitment_home_timezone_v2"
    private let defaults: UserDefaults
    private var legacyDailyEarnings: [String: Int] = [:]
    private var legacyAwardedEasyCycleIDs: Set<UUID> = []
    private var homeTimeZoneIdentifier = TimeZone.current.identifier
    private var isLoading = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isLoading = true
        let didRepairRecruitmentState = load()
        isLoading = false
        if didRepairRecruitmentState {
            persist()
        }
    }

    @discardableResult
    func awardBBBucks(
        forEasyCycle cycleID: UUID,
        superseding replacedCycleIDs: [UUID] = [],
        completedAt: Date,
        isPlusActive: Bool,
        now: Date = Date()
    ) -> BBBuckAwardResult {
        let transactionID = "easy:\(cycleID.uuidString.lowercased())"
        let dayID = careDayID(for: completedAt)
        let rewardedCount = rewardedCycleCount(onCareDayID: dayID)

        let equivalentCycleIDs = Set(replacedCycleIDs + [cycleID])
        guard equivalentCycleIDs.isDisjoint(with: legacyAwardedEasyCycleIDs),
              !transactions.contains(where: {
                  $0.id == transactionID
                      || $0.cycleID.map(equivalentCycleIDs.contains) == true
              }) else {
            return BBBuckAwardResult(
                status: .duplicate,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCount
            )
        }
        guard careDayID(for: now) == dayID else {
            return BBBuckAwardResult(
                status: .historical,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCount
            )
        }
        guard rewardedCount < Self.dailyRewardedCycleLimit else {
            return BBBuckAwardResult(
                status: .dailyLimitReached,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCount
            )
        }

        let plusBonus = isPlusActive ? Self.plusCycleBonus : 0
        let transaction = BBBuckTransaction(
            id: transactionID,
            source: .dailyTask,
            cycleID: cycleID,
            careDayID: dayID,
            baseAmount: Self.baseCycleReward,
            plusBonus: plusBonus,
            createdAt: now,
            taskID: .easyCycle,
            referenceID: cycleID.uuidString.lowercased()
        )
        guard appendTransaction(transaction) else {
            return BBBuckAwardResult(
                status: .dailyLimitReached,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCount
            )
        }
        return BBBuckAwardResult(
            status: .awarded,
            baseAmount: transaction.baseAmount,
            plusBonus: transaction.plusBonus,
            rewardedCycleCount: rewardedCount + 1
        )
    }

    @discardableResult
    func awardDailyTask(
        _ taskID: DailyTaskID,
        eventDate: Date,
        referenceID: String? = nil,
        now: Date = Date()
    ) -> BBBuckAwardResult {
        guard taskID != .easyCycle else {
            return BBBuckAwardResult(
                status: .historical,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCycleCount(onCareDayID: careDayID(for: now))
            )
        }
        let todayID = careDayID(for: now)
        let eventDayID = careDayID(for: eventDate)
        guard todayID == eventDayID else {
            return BBBuckAwardResult(
                status: .historical,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCycleCount(onCareDayID: todayID)
            )
        }

        let transactionID = "daily:\(todayID):\(taskID.rawValue)"
        guard !transactions.contains(where: { $0.id == transactionID }) else {
            return BBBuckAwardResult(
                status: .duplicate,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCycleCount(onCareDayID: todayID)
            )
        }

        let transaction = BBBuckTransaction(
            id: transactionID,
            source: .dailyTask,
            cycleID: nil,
            careDayID: todayID,
            baseAmount: taskID.rewardAmount,
            plusBonus: 0,
            createdAt: now,
            taskID: taskID,
            referenceID: referenceID
        )
        guard appendTransaction(transaction) else {
            return BBBuckAwardResult(
                status: .dailyLimitReached,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCycleCount(onCareDayID: todayID)
            )
        }
        return BBBuckAwardResult(
            status: .awarded,
            baseAmount: transaction.baseAmount,
            plusBonus: 0,
            rewardedCycleCount: rewardedCycleCount(onCareDayID: todayID)
        )
    }

    @discardableResult
    func awardAchievement(
        milestoneID: String?,
        kind: AchievementMilestoneKind?,
        now: Date = Date()
    ) -> BBBuckAwardResult {
        let reward = kind?.bbBucksReward ?? 0
        guard let milestoneID, reward > 0 else {
            return BBBuckAwardResult(
                status: .historical,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCycleCount(onCareDayID: careDayID(for: now))
            )
        }

        let transactionID = "achievement:\(milestoneID)"
        guard !transactions.contains(where: { $0.id == transactionID }) else {
            return BBBuckAwardResult(
                status: .duplicate,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCycleCount(onCareDayID: careDayID(for: now))
            )
        }

        let transaction = BBBuckTransaction(
            id: transactionID,
            source: .achievement,
            cycleID: nil,
            careDayID: careDayID(for: now),
            baseAmount: reward,
            plusBonus: 0,
            createdAt: now,
            referenceID: milestoneID
        )
        guard appendTransaction(transaction) else {
            return BBBuckAwardResult(
                status: .dailyLimitReached,
                baseAmount: 0,
                plusBonus: 0,
                rewardedCycleCount: rewardedCycleCount(onCareDayID: careDayID(for: now))
            )
        }
        return BBBuckAwardResult(
            status: .awarded,
            baseAmount: reward,
            plusBonus: 0,
            rewardedCycleCount: rewardedCycleCount(onCareDayID: careDayID(for: now))
        )
    }

    func dailyTaskProgress(_ taskID: DailyTaskID, on date: Date = Date(), isPlusActive: Bool = false) -> DailyTaskProgress {
        let dayID = careDayID(for: date)
        let completedCount: Int
        if taskID == .easyCycle {
            completedCount = rewardedCycleCount(onCareDayID: dayID)
        } else {
            completedCount = transactions.contains {
                $0.careDayID == dayID && $0.source == .dailyTask && $0.taskID == taskID
            } ? 1 : 0
        }
        return DailyTaskProgress(
            taskID: taskID,
            completedCount: min(completedCount, taskID.targetCount),
            targetCount: taskID.targetCount,
            rewardAmount: taskID.rewardAmount,
            plusRewardAmount: taskID == .easyCycle && isPlusActive ? Self.plusCycleBonus : 0
        )
    }

    func completedDailyTaskCount(on date: Date = Date()) -> Int {
        DailyTaskID.allCases.filter { dailyTaskProgress($0, on: date).isCompleted }.count
    }

    func earnedBBBucks(on date: Date) -> Int {
        let dayID = careDayID(for: date)
        let current = transactions
            .filter { $0.careDayID == dayID }
            .reduce(0) { BBBuckLedgerLimits.add($0, max($1.amount, 0)) ?? $0 }
        return max(current, min(max(legacyDailyEarnings[dayID] ?? 0, 0), BBBuckLedgerLimits.maxBalanceMagnitude))
    }

    func baseBBBucks(on date: Date) -> Int {
        let dayID = careDayID(for: date)
        return transactions
            .filter { $0.careDayID == dayID }
            .reduce(0) { BBBuckLedgerLimits.add($0, max($1.baseAmount, 0)) ?? $0 }
    }

    func plusBonusBBBucks(on date: Date) -> Int {
        let dayID = careDayID(for: date)
        return transactions
            .filter { $0.careDayID == dayID }
            .reduce(0) { BBBuckLedgerLimits.add($0, max($1.plusBonus, 0)) ?? $0 }
    }

    func rewardedCycleCount(on date: Date) -> Int {
        rewardedCycleCount(onCareDayID: careDayID(for: date))
    }

    func remainingEarnableBBBucks(on date: Date) -> Int {
        max(Self.dailyRewardedCycleLimit - rewardedCycleCount(on: date), 0) * Self.baseCycleReward
    }

    func report(for key: String) -> YesterdayReport? {
        reports.first { $0.reportKey == key }
    }

    func latestReport() -> YesterdayReport? {
        reports.sorted { $0.date > $1.date }.first
    }

    func storeReport(_ report: YesterdayReport) {
        if let index = reports.firstIndex(where: { $0.reportKey == report.reportKey }) {
            reports[index] = report
        } else {
            reports.append(report)
        }
        reports.sort { $0.date > $1.date }
    }

    func isRecruited(_ companionID: String) -> Bool {
        let canonicalID = BabyCompanion.canonicalID(companionID)
        return recruitedIDs.contains {
            BabyCompanion.canonicalID($0) == canonicalID
        }
    }

    func isUnlocked(_ companion: BabyCompanion, selectedID: String, temperamentAnimalID: String?) -> Bool {
        guard !BabyCompanion.previewLockedIDs.contains(BabyCompanion.canonicalID(companion.id)) else {
            return false
        }
        return companion.isUnlocked(selectedID: selectedID, temperamentAnimalID: temperamentAnimalID) || isRecruited(companion.id)
    }

    func friendshipPercent(for companionID: String) -> Double {
        let target = max(BabyCompanion.companion(for: companionID).friendshipTarget, 1)
        return min(max(Double(friendshipValue(for: companionID)) / Double(target), 0), 1)
    }

    func friendshipValue(for companionID: String) -> Int {
        max(friendshipValues[companionID] ?? 0, 0)
    }

    func remainingFriendship(for companionID: String) -> Int {
        guard !isRecruited(companionID) else { return 0 }
        let companion = BabyCompanion.companion(for: companionID)
        return max(companion.friendshipTarget - friendshipValue(for: companionID), 0)
    }

    @discardableResult
    func invite(companionID: String, amount requestedAmount: Int, now: Date = Date()) -> CompanionInvitationResult? {
        let canonicalID = BabyCompanion.canonicalID(companionID)
        guard !BabyCompanion.defaultUnlockedIDs.contains(canonicalID), !isRecruited(canonicalID) else { return nil }
        let remaining = remainingFriendship(for: canonicalID)
        guard requestedAmount > 0,
              requestedAmount <= bbBucks,
              requestedAmount <= remaining else { return nil }
        let spend = requestedAmount

        let companion = BabyCompanion.companion(for: canonicalID)
        let transaction = BBBuckTransaction(
            id: "invite:\(UUID().uuidString.lowercased())",
            source: .buddyInvitation,
            cycleID: nil,
            careDayID: careDayID(for: now),
            baseAmount: -spend,
            plusBonus: 0,
            createdAt: now,
            referenceID: companion.id,
            companionID: companion.id
        )
        guard appendTransaction(transaction) else { return nil }

        let nextValue = min(
            BBBuckLedgerLimits.add(friendshipValue(for: companion.id), spend) ?? companion.friendshipTarget,
            companion.friendshipTarget
        )
        friendshipValues[companion.id] = nextValue
        if nextValue >= companion.friendshipTarget {
            recruitedIDs.insert(companion.id)
        }
        return CompanionInvitationResult(
            companionID: companion.id,
            spentBucks: spend,
            friendshipServings: spend,
            progress: Double(nextValue) / Double(max(companion.friendshipTarget, 1)),
            didRecruit: nextValue >= companion.friendshipTarget,
            isBonus: false
        )
    }

    func exportSnapshot() -> CompanionRecruitmentSnapshot {
        CompanionRecruitmentLedgerMerger.sanitizedSnapshot(CompanionRecruitmentSnapshot(
            bbBucks: bbBucks,
            balanceAnchor: nil,
            friendshipValues: friendshipValues,
            recruitedIDs: recruitedIDs,
            transactions: transactions,
            historicalImportSettlement: historicalImportSettlement
        ))
    }

    func importSnapshot(_ snapshot: CompanionRecruitmentSnapshot) {
        let safeSnapshot = CompanionRecruitmentLedgerMerger.sanitizedSnapshot(snapshot)
        isLoading = true
        bbBucks = max(safeSnapshot.bbBucks, 0)
        friendshipValues = safeSnapshot.friendshipValues
        recruitedIDs = Set(safeSnapshot.recruitedIDs.map(BabyCompanion.canonicalID(_:)))
        transactions = safeSnapshot.transactions
        historicalImportSettlement = safeSnapshot.historicalImportSettlement
        _ = reconcileRecruitedIDsFromFriendship()
        isLoading = false
        persist()
    }

    @discardableResult
    func settleHistoricalEasyCycles(_ cycles: [EasyCycle], importFingerprint: String, now: Date = Date()) -> Int {
        guard !historicalImportSettlement.importFingerprints.contains(importFingerprint) else { return 0 }
        var remainingLifetimeAmount = max(
            Self.historicalImportLifetimeLimit - historicalImportSettlement.awardedAmount,
            0
        )
        var awarded = 0
        var awardedPerDay: [String: Int] = [:]

        for cycle in cycles.sorted(by: { ($0.endedAt ?? $0.updatedAt) < ($1.endedAt ?? $1.updatedAt) }) {
            guard remainingLifetimeAmount >= Self.baseCycleReward else { break }
            let phases = Set(cycle.linkedRecords.map(\.phase))
            guard phases.contains(.eat), phases.contains(.activity), phases.contains(.sleep) else { continue }

            let transactionID = "import:\(cycle.id.uuidString.lowercased())"
            guard !transactions.contains(where: { $0.id == transactionID || $0.cycleID == cycle.id }) else { continue }
            let completedAt = cycle.endedAt ?? cycle.updatedAt
            let dayID = careDayID(for: completedAt)
            let dayCount = awardedPerDay[dayID] ?? transactions.filter {
                $0.careDayID == dayID
                    && ($0.source == .easyCycle
                        || $0.source == .historicalImport
                        || ($0.source == .dailyTask && $0.taskID == .easyCycle))
            }.count
            guard dayCount < Self.dailyRewardedCycleLimit else { continue }

            let transaction = BBBuckTransaction(
                id: transactionID,
                source: .historicalImport,
                cycleID: cycle.id,
                careDayID: dayID,
                baseAmount: Self.baseCycleReward,
                plusBonus: 0,
                createdAt: now
            )
            guard appendTransaction(transaction) else { continue }
            awardedPerDay[dayID] = dayCount + 1
            awarded = BBBuckLedgerLimits.add(awarded, transaction.amount) ?? awarded
            remainingLifetimeAmount = max(
                remainingLifetimeAmount - transaction.amount,
                0
            )
        }

        historicalImportSettlement.awardedAmount = min(
            BBBuckLedgerLimits.add(historicalImportSettlement.awardedAmount, awarded) ?? historicalImportSettlement.awardedAmount,
            Self.historicalImportLifetimeLimit
        )
        historicalImportSettlement.importFingerprints.insert(importFingerprint)
        return awarded
    }

    @discardableResult
    private func load() -> Bool {
        bbBucks = BBBuckLedgerLimits.clampBalance(defaults.integer(forKey: bbBucksKey))
        if let data = defaults.data(forKey: friendshipValuesKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            friendshipValues = Dictionary(
                decoded
                    .filter { !$0.key.isEmpty && (0...100_000).contains($0.value) }
                    .prefix(256)
                    .map { ($0.key, $0.value) },
                uniquingKeysWith: { current, _ in current }
            )
        } else if let data = defaults.data(forKey: friendshipKey),
                  data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
                  let legacy = try? JSONDecoder().decode([String: Double].self, from: data) {
            friendshipValues = legacy.reduce(into: [:]) { values, entry in
                guard entry.key.isEmpty == false, entry.value.isFinite else { return }
                let target = BabyCompanion.companion(for: entry.key).friendshipTarget
                let progress = min(max(entry.value, 0), 1)
                values[entry.key] = min(max(Int((progress * Double(target)).rounded()), 0), target)
            }
        }
        if let data = defaults.data(forKey: recruitedKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            recruitedIDs = Set(decoded.filter { !$0.isEmpty }.prefix(256).map(BabyCompanion.canonicalID(_:)))
        }
        if let data = defaults.data(forKey: reportsKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode([YesterdayReport].self, from: data) {
            reports = Array(decoded.prefix(2_000).sorted { $0.date > $1.date })
        }
        if let data = defaults.data(forKey: transactionsKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode([BBBuckTransaction].self, from: data) {
            transactions = CompanionRecruitmentLedgerMerger.sanitizedTransactions(decoded)
        }
        if let data = defaults.data(forKey: historicalImportKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode(HistoricalImportSettlement.self, from: data) {
            historicalImportSettlement = HistoricalImportSettlement(
                awardedAmount: min(max(decoded.awardedAmount, 0), Self.historicalImportLifetimeLimit),
                importFingerprints: Set(decoded.importFingerprints.filter { !$0.isEmpty }.prefix(256))
            )
        }
        if let storedTimeZone = defaults.string(forKey: homeTimeZoneKey), TimeZone(identifier: storedTimeZone) != nil {
            homeTimeZoneIdentifier = storedTimeZone
        } else {
            homeTimeZoneIdentifier = TimeZone.current.identifier
            defaults.set(homeTimeZoneIdentifier, forKey: homeTimeZoneKey)
        }
        if let data = defaults.data(forKey: dailyEarningsKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            legacyDailyEarnings = Dictionary(
                decoded
                    .filter { !$0.key.isEmpty && $0.value >= 0 && $0.value <= BBBuckLedgerLimits.maxBalanceMagnitude }
                    .prefix(512)
                    .map { ($0.key, $0.value) },
                uniquingKeysWith: { current, _ in current }
            )
        }
        if let data = defaults.data(forKey: awardedEasyCycleIDsKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            legacyAwardedEasyCycleIDs = Set(decoded.prefix(10_000))
        }
        return reconcileRecruitedIDsFromFriendship()
    }

    private func reconcileRecruitedIDsFromFriendship() -> Bool {
        var normalizedRecruitedIDs = Set(recruitedIDs.map(BabyCompanion.canonicalID(_:)))
        for companion in BabyCompanion.all {
            let canonicalID = BabyCompanion.canonicalID(companion.id)
            guard !BabyCompanion.defaultUnlockedIDs.contains(canonicalID),
                  friendshipValues[canonicalID, default: 0] >= companion.friendshipTarget else {
                continue
            }
            normalizedRecruitedIDs.insert(canonicalID)
        }

        guard normalizedRecruitedIDs != recruitedIDs else { return false }
        recruitedIDs = normalizedRecruitedIDs
        return true
    }

    private func persistIfLoaded() {
        guard !isLoading else { return }
        persist()
    }

    @discardableResult
    private func appendTransaction(_ transaction: BBBuckTransaction) -> Bool {
        guard transactions.count < BBBuckLedgerLimits.maxTransactions,
              transaction.checkedAmount != nil,
              let nextBalance = BBBuckLedgerLimits.add(bbBucks, transaction.amount),
              nextBalance >= 0 else {
            return false
        }
        transactions.append(transaction)
        bbBucks = nextBalance
        return true
    }

    private static func deduplicatedTransactions(_ transactions: [BBBuckTransaction]) -> [BBBuckTransaction] {
        CompanionRecruitmentLedgerMerger.sanitizedTransactions(transactions)
    }

    private func persist() {
        defaults.set(bbBucks, forKey: bbBucksKey)
        if let data = try? JSONEncoder().encode(friendshipValues) {
            defaults.set(data, forKey: friendshipValuesKey)
        }
        if let data = try? JSONEncoder().encode(recruitedIDs) {
            defaults.set(data, forKey: recruitedKey)
        }
        if let data = try? JSONEncoder().encode(reports) {
            defaults.set(data, forKey: reportsKey)
        }
        if let data = try? JSONEncoder().encode(transactions) {
            defaults.set(data, forKey: transactionsKey)
        }
        if let data = try? JSONEncoder().encode(historicalImportSettlement) {
            defaults.set(data, forKey: historicalImportKey)
        }
    }

    private func careDayID(for date: Date) -> String {
        let formatter = DateFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: homeTimeZoneIdentifier) ?? .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func rewardedCycleCount(onCareDayID careDayID: String) -> Int {
        transactions.filter {
            $0.careDayID == careDayID
                && ($0.source == .easyCycle || ($0.source == .dailyTask && $0.taskID == .easyCycle))
        }.count
    }

}

struct CompanionInvitationResult {
    let companionID: String
    let spentBucks: Int
    let friendshipServings: Int
    let progress: Double
    let didRecruit: Bool
    let isBonus: Bool
}

@MainActor
final class SceneEntitlementStore: ObservableObject {
    static let shared = SceneEntitlementStore()

    static let freeSceneIDs: Set<String> = ["scene_01", "scene_02", "scene_03"]
    static let rules: [String: SceneUnlockRule] = [
        "scene_04": .milestone("one-month"),
        "scene_05": .achievementCount(5),
        "scene_06": .milestone("hundred-days"),
        "scene_07": .achievementCount(10),
        "scene_08": .achievementCount(15),
        "scene_09": .milestone("first-birthday")
    ]
    private static let legacySceneIDMap: [String: String] = [
        "cozyRoom": "scene_01",
        "sunnyNursery": "scene_02",
        "sunnyNurseryDaylight": "scene_02",
        "moonlitRoom": "scene_03",
        "moonlitRoomStarlight": "scene_03",
        "scene_s04": "scene_04",
        "scene_s05": "scene_05",
        "scene_s06": "scene_06",
        "scene_s07": "scene_07",
        "scene_s08": "scene_08",
        "scene_s09": "scene_09"
    ]

    @Published private(set) var entitlements: [SceneEntitlement] = []
    @Published private(set) var latestAwardedSceneIDs: [String] = []

    private let storageKey = "companion_scene_entitlements_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode([SceneEntitlement].self, from: data) {
            entitlements = Self.deduplicatedEntitlements(decoded)
        }
    }

    func isOwned(_ sceneID: String) -> Bool {
        let canonicalID = Self.canonicalSceneID(sceneID)
        return Self.freeSceneIDs.contains(canonicalID)
            || entitlements.contains { Self.canonicalSceneID($0.sceneID) == canonicalID }
    }

    @discardableResult
    func evaluate(achievements: [CustomAchievement], awardedAt: Date = Date()) -> [String] {
        let validCount = validAchievementCount(achievements)
        var newlyAwarded: [String] = []

        for (sceneID, rule) in Self.rules.sorted(by: { $0.key < $1.key }) where !isOwned(sceneID) {
            let sourceAchievement: CustomAchievement?
            switch rule {
            case .free, .plusVariant(_), .event(_):
                sourceAchievement = nil
            case .milestone(let milestoneID):
                sourceAchievement = achievements.first { $0.milestoneID == milestoneID || $0.templateID == milestoneID }
                guard sourceAchievement != nil else { continue }
            case .achievementCount(let threshold):
                guard validCount >= threshold else { continue }
                sourceAchievement = achievements.sorted { $0.completedAt > $1.completedAt }.first
            }

            entitlements.append(SceneEntitlement(
                id: "scene-entitlement:\(sceneID)",
                sceneID: sceneID,
                awardedAt: awardedAt,
                sourceAchievementID: sourceAchievement?.id
            ))
            newlyAwarded.append(sceneID)
        }

        if !newlyAwarded.isEmpty {
            persist()
            latestAwardedSceneIDs = newlyAwarded
        }
        return newlyAwarded
    }

    func consumeLatestAwards() -> [String] {
        let awards = latestAwardedSceneIDs
        latestAwardedSceneIDs = []
        return awards
    }

    func exportEntitlements() -> [SceneEntitlement] {
        Self.deduplicatedEntitlements(entitlements)
    }

    func importEntitlements(_ incoming: [SceneEntitlement]) {
        entitlements = Self.deduplicatedEntitlements(
            Array((entitlements + incoming).prefix(256))
        )
        persist()
    }

    static func canonicalSceneID(_ sceneID: String) -> String {
        legacySceneIDMap[sceneID] ?? sceneID
    }

    private static func deduplicatedEntitlements(_ entitlements: [SceneEntitlement]) -> [SceneEntitlement] {
        var bySceneID: [String: SceneEntitlement] = [:]
        for entitlement in entitlements {
            let canonicalID = canonicalSceneID(entitlement.sceneID)
            let normalized = SceneEntitlement(
                id: "scene-entitlement:\(canonicalID)",
                sceneID: canonicalID,
                awardedAt: entitlement.awardedAt,
                sourceAchievementID: entitlement.sourceAchievementID
            )
            if let existing = bySceneID[canonicalID] {
                if normalized.awardedAt < existing.awardedAt {
                    bySceneID[canonicalID] = normalized
                }
            } else {
                bySceneID[canonicalID] = normalized
            }
        }
        return Array(bySceneID.values.sorted {
            if $0.awardedAt == $1.awardedAt { return $0.sceneID < $1.sceneID }
            return $0.awardedAt < $1.awardedAt
        }.prefix(256))
    }

    private func validAchievementCount(_ achievements: [CustomAchievement]) -> Int {
        var keys: Set<String> = []
        for achievement in achievements {
            guard achievement.milestoneKind != .custom,
                  let milestoneID = achievement.milestoneID ?? achievement.templateID else {
                continue
            }
            keys.insert("milestone:\(milestoneID)")
        }
        return keys.count
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entitlements) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Tabs

enum RootTab: Int, CaseIterable {
    case record
    case companion
    case growth

    var title: String {
        switch self {
        case .record: return "记录".localized
        case .companion: return "陪伴".localized
        case .growth: return "成长".localized
        }
    }

    var icon: String {
        switch self {
        case .record: return "book.fill"
        case .companion: return "heart.fill"
        case .growth: return "trophy.fill"
        }
    }

    var assetIconName: String {
        switch self {
        case .record: return "nav_record_icon"
        case .companion: return "nav_companion_icon"
        case .growth: return "nav_growth_icon"
        }
    }
}

// MARK: - Actions

enum BabyAction: String, CaseIterable, Identifiable, Codable {
    case idle
    case shake
    case pet
    case poke
    case listen
    case nursing
    case diaper
    case breastfeed
    case sleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle: return "待机".localized
        case .shake: return "摇一摇".localized
        case .pet: return "抚摸".localized
        case .poke: return "戳一戳".localized
        case .listen: return "听".localized
        case .nursing: return "记录喂养".localized
        case .diaper: return "记录尿布".localized
        case .breastfeed: return "记录吸乳".localized
        case .sleep: return "记录睡眠".localized
        }
    }

    var emojiIcon: String {
        switch self {
        case .idle: return "💤"
        case .shake: return "🫨"
        case .pet: return "🤲"
        case .poke: return "👉"
        case .listen: return "👂"
        case .nursing: return "🍼"
        case .diaper: return "🧷"
        case .breastfeed: return "∞"
        case .sleep: return "🌙"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "sparkles"
        case .shake: return "iphone.radiowaves.left.and.right"
        case .pet: return "hand.draw.fill"
        case .poke: return "hand.tap.fill"
        case .listen: return "mic.fill"
        case .nursing: return "babybottle.fill"
        case .diaper: return "drop.fill"
        case .breastfeed: return "infinity"
        case .sleep: return "moon.fill"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .idle: return 0
        case .shake: return 2.5
        case .pet: return 2.0
        case .poke: return 1.5
        case .listen: return 3.0
        case .nursing, .diaper, .breastfeed, .sleep: return 1.8
        }
    }

    var isBasicInteraction: Bool {
        switch self {
        case .shake, .pet, .poke, .listen: return true
        default: return false
        }
    }

    var isRecordable: Bool {
        switch self {
        case .nursing, .diaper, .breastfeed, .sleep: return true
        default: return false
        }
    }
}

struct ActivityLog: Identifiable, Codable {
    let id: UUID
    let action: BabyAction
    let timestamp: Date

    init(id: UUID = UUID(), action: BabyAction, timestamp: Date = Date()) {
        self.id = id
        self.action = action
        self.timestamp = timestamp
    }
}

// MARK: - Baby Profile

enum BabyGender: String, Codable, CaseIterable, Identifiable {
    case boy = "Boy"
    case girl = "Girl"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .boy: return "👦🏻"
        case .girl: return "👧🏻"
        }
    }
}

struct WidgetBabyInfo: Codable {
    var name: String
    var birthDate: Date

    func ageMonths(asOf date: Date = Date()) -> Int {
        max(Calendar.current.dateComponents([.month], from: birthDate, to: date).month ?? 0, 0)
    }
}

enum WidgetStorageKey {
    static let appGroupID = "group.73AUQDMCJ2.babybuddy"
    static let feedingSessions = "feeding_sessions"
    static let careRecords = "care_records_v1"
    static let careRecencySnapshot = "care_recency_snapshot_v1"
    static let babyInfo = "baby_info"
    static let lastFeedingWidgetKind = "v.babybuddy.LastFeeding"
}

enum BabyAvatarSourceKind: String, Codable, Hashable {
    case emoji
    case photo
    case companion
    case video
}

struct BabyAvatarSnapshot: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var sourceKind: BabyAvatarSourceKind
    var emoji: String?
    var imageData: Data?
    var companionID: String?
    var videoFilename: String?
    var createdAt: Date = Date()
}

struct BabyProfileData: Codable {
    var name: String
    var gender: BabyGender
    var birthDate: Date
    var heightCm: Double? = nil
    var weightKg: Double? = nil
    var avatarEmoji: String?
    var avatarImageData: Data?
    var avatarCompanionID: String? = nil
    var avatarVideoFilename: String? = nil
    var avatarHistory: [BabyAvatarSnapshot]? = nil
    var avatarMotionEnabled: Bool? = nil

    var displayAvatar: String {
        avatarEmoji ?? gender.emoji
    }

    var avatarSourceKind: BabyAvatarSourceKind {
        if avatarVideoFilename != nil {
            return .video
        }
        if avatarImageData != nil {
            return .photo
        }
        if avatarCompanionID != nil {
            return .companion
        }
        return .emoji
    }

    var avatarHistoryItems: [BabyAvatarSnapshot] {
        avatarHistory ?? []
    }

    var isAvatarMotionEnabled: Bool {
        avatarMotionEnabled ?? true
    }

    var avatarSnapshot: BabyAvatarSnapshot {
        BabyAvatarSnapshot(
            sourceKind: avatarSourceKind,
            emoji: avatarEmoji,
            imageData: avatarImageData,
            companionID: avatarCompanionID,
            videoFilename: avatarVideoFilename,
            createdAt: Date()
        )
    }

    var ageMonths: Int {
        max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
    }

    var ageDays: Int {
        max(Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0, 0)
    }

    var ageDisplayText: String {
        BabyAgeFormatter.displayText(birthDate: birthDate, on: Date())
    }

    func widgetInfo() -> WidgetBabyInfo {
        WidgetBabyInfo(name: name, birthDate: birthDate)
    }
}

extension BabyAvatarSnapshot {
    var isRenderable: Bool {
        switch sourceKind {
        case .photo:
            return imageData != nil
        case .companion:
            return companionID != nil
        case .video:
            return videoFilename != nil
        case .emoji:
            return emoji != nil
        }
    }

    func isSameAvatar(as other: BabyAvatarSnapshot) -> Bool {
        sourceKind == other.sourceKind
            && emoji == other.emoji
            && imageData == other.imageData
            && companionID == other.companionID
            && videoFilename == other.videoFilename
    }
}

struct BabyProfileAvatarView: View {
    let profile: BabyProfileData
    var size: CGFloat
    var emojiSize: CGFloat
    var lineWidth: CGFloat = 1.5
    var motionScale: CGFloat = 1
    var allowsMotion: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if profile.avatarSourceKind == .emoji {
                BabyDefaultAvatarView(size: size, lineWidth: lineWidth)
            } else {
                BabyAvatarContentView(
                    sourceKind: profile.avatarSourceKind,
                    emoji: profile.displayAvatar,
                    imageData: profile.avatarImageData,
                    companionID: profile.avatarCompanionID,
                    videoFilename: profile.avatarVideoFilename,
                    size: size,
                    emojiSize: emojiSize,
                    lineWidth: lineWidth,
                    motionEnabled: allowsMotion && profile.isAvatarMotionEnabled && !reduceMotion,
                    motionScale: motionScale
                )
            }
        }
    }
}

private struct BabyDefaultAvatarView: View {
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignToken.surfaceRaised.opacity(0.98),
                            DesignToken.primary.opacity(0.18),
                            DesignToken.accentBlue.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "figure.child")
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(DesignToken.primary)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.95), DesignToken.primary.opacity(0.70)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )
        )
        .contentShape(Circle())
    }
}

struct BabyAvatarSnapshotView: View {
    let snapshot: BabyAvatarSnapshot
    let fallbackEmoji: String
    var size: CGFloat
    var emojiSize: CGFloat
    var isSelected: Bool = false

    var body: some View {
        BabyAvatarContentView(
            sourceKind: snapshot.sourceKind,
            emoji: snapshot.emoji ?? fallbackEmoji,
            imageData: snapshot.imageData,
            companionID: snapshot.companionID,
            videoFilename: snapshot.videoFilename,
            size: size,
            emojiSize: emojiSize,
            lineWidth: isSelected ? 2.5 : 1.2,
            motionEnabled: true,
            motionScale: 0.8
        )
    }
}

private struct BabyAvatarContentView: View {
    let sourceKind: BabyAvatarSourceKind
    let emoji: String
    let imageData: Data?
    let companionID: String?
    let videoFilename: String?
    let size: CGFloat
    let emojiSize: CGFloat
    let lineWidth: CGFloat
    let motionEnabled: Bool
    let motionScale: CGFloat

    var body: some View {
        Group {
            // A video is already animated by AVPlayerLayer. Driving that layer through
            // TimelineView as well causes 24 SwiftUI updates per second and can make
            // UIKit-backed avatars briefly detach or render an empty frame.
            if motionEnabled && sourceKind != .video {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    avatarFrame(phase: avatarPhase(at: context.date))
                }
            } else {
                avatarFrame(phase: .zero)
            }
        }
        .frame(width: size, height: size)
    }

    private func avatarFrame(phase: BabyAvatarMotionPhase) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.98),
                            DesignToken.primary.opacity(0.16),
                            DesignToken.accentBlue.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: DesignToken.shadowColor.opacity(size > 52 ? 0.10 : 0.05), radius: size > 52 ? 12 : 5, y: size > 52 ? 6 : 2)

            avatarImage
                .scaleEffect(1 + phase.scale)
                .rotationEffect(.degrees(phase.rotation))
                .offset(y: phase.offset)
                .animation(nil, value: phase.offset)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.95),
                            DesignToken.primary.opacity(0.70)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )
        )
        .contentShape(Circle())
    }

    @ViewBuilder
    private var avatarImage: some View {
        switch sourceKind {
        case .photo:
            DecodedAvatarPhotoView(
                imageData: imageData,
                fallbackEmoji: emoji,
                size: size,
                emojiSize: emojiSize
            )
        case .companion:
            if let companionID {
                Image(BabyCompanion.companion(for: companionID).portraitAssetName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.09)
            } else {
                defaultAvatarSymbol
            }
        case .emoji:
            defaultAvatarSymbol
        case .video:
            if let videoFilename,
               let url = BabyAvatarVideoStore.url(for: videoFilename) {
                LoopingAvatarVideoView(url: url)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                defaultAvatarSymbol
            }
        }
    }

    private var defaultAvatarSymbol: some View {
        Image(systemName: "figure.child")
            .font(.system(size: emojiSize * 0.72, weight: .semibold))
            .foregroundStyle(DesignToken.primary)
    }

    private func avatarPhase(at date: Date) -> BabyAvatarMotionPhase {
        let elapsed = date.timeIntervalSinceReferenceDate
        let wave = sin(elapsed * 2.4)
        let secondary = sin(elapsed * 1.25 + 0.7)
        return BabyAvatarMotionPhase(
            offset: CGFloat(wave) * 1.3 * motionScale,
            rotation: secondary * 1.8 * Double(motionScale),
            scale: CGFloat((wave + 1) * 0.006) * motionScale
        )
    }
}

private struct BabyAvatarMotionPhase {
    var offset: CGFloat
    var rotation: Double
    var scale: CGFloat

    static let zero = BabyAvatarMotionPhase(offset: .zero, rotation: 0, scale: .zero)
}

private struct DecodedAvatarPhotoView: View {
    let imageData: Data?
    let fallbackEmoji: String
    let size: CGFloat
    let emojiSize: CGFloat

    @State private var decodedImage: UIImage?

    var body: some View {
        Group {
            if let decodedImage {
                Image(uiImage: decodedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "figure.child")
                    .font(.system(size: emojiSize * 0.72, weight: .semibold))
                    .foregroundStyle(DesignToken.primary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: imageData) {
            decodedImage = await decodeImage(from: imageData)
        }
    }

    private func decodeImage(from data: Data?) async -> UIImage? {
        guard let data else { return nil }
        return await Task.detached(priority: .utility) {
            UIImage(data: data)
        }.value
    }
}

enum BabyAvatarVideoStore {
    private static let directoryName = "BabyAvatarVideos"

    static func saveVideo(from temporaryURL: URL) throws -> String {
        let filename = "avatar-\(UUID().uuidString).mov"
        let destination = try directoryURL().appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: temporaryURL, to: destination)
        return filename
    }

    static func url(for filename: String) -> URL? {
        guard filename.hasPrefix("avatar-"),
              filename.utf8.count <= 255,
              !filename.contains("/"),
              !filename.contains("\\"),
              (filename as NSString).pathExtension.lowercased() == "mov" else {
            return nil
        }
        guard let directory = try? directoryURL() else { return nil }
        let url = directory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func directoryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}

private struct LoopingAvatarVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.configure(url: url)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.configure(url: url)
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Void) {
        uiView.cleanup()
    }

    final class PlayerView: UIView {
        private let playerLayer = AVPlayerLayer()
        private let placeholderView = UIImageView(
            image: UIImage(systemName: "figure.child")
        )
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?
        private var readyForDisplayObservation: NSKeyValueObservation?

        override init(frame: CGRect) {
            super.init(frame: frame)
            prepareView()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            prepareView()
        }

        private func prepareView() {
            backgroundColor = .clear
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)

            placeholderView.contentMode = .scaleAspectFit
            placeholderView.tintColor = UIColor(named: "BB_PrimaryAction") ?? .systemPurple
            addSubview(placeholderView)

            readyForDisplayObservation = playerLayer.observe(
                \.isReadyForDisplay,
                options: [.initial, .new]
            ) { [weak self] layer, _ in
                DispatchQueue.main.async {
                    self?.placeholderView.isHidden = layer.isReadyForDisplay
                }
            }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationWillResignActive),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
            placeholderView.frame = bounds.insetBy(
                dx: bounds.width * 0.30,
                dy: bounds.height * 0.30
            )
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                player?.pause()
            } else {
                resumePlayback()
            }
        }

        func configure(url: URL) {
            if currentURL == url {
                resumePlayback()
                return
            }

            replacePlayer(with: url)
            resumePlayback()
        }

        private func replacePlayer(with url: URL) {
            releasePlayer(keepingURL: true)
            currentURL = url
            placeholderView.isHidden = false

            let item = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = true
            queuePlayer.actionAtItemEnd = .none
            playerLayer.player = queuePlayer
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
        }

        private func resumePlayback() {
            guard window != nil, UIApplication.shared.applicationState == .active else {
                return
            }
            if let currentURL,
               player == nil || player?.items().isEmpty == true {
                replacePlayer(with: currentURL)
            }
            player?.play()
        }

        @objc private func applicationDidBecomeActive() {
            resumePlayback()
        }

        @objc private func applicationWillResignActive() {
            player?.pause()
        }

        func cleanup() {
            releasePlayer(keepingURL: false)
        }

        private func releasePlayer(keepingURL: Bool) {
            player?.pause()
            looper?.disableLooping()
            looper = nil
            player?.removeAllItems()
            player = nil
            playerLayer.player = nil
            placeholderView.isHidden = false
            if !keepingURL {
                currentURL = nil
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            readyForDisplayObservation?.invalidate()
        }
    }
}

struct BabyProfile: Codable {
    var name: String
    var gender: String
    var birthDate: Date

    var ageDays: Int {
        max(Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0, 0)
    }

    var ageMonths: Int {
        max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
    }

    var data: BabyProfileData {
        BabyProfileData(
            name: name,
            gender: gender == BabyGender.girl.rawValue ? .girl : .boy,
            birthDate: birthDate,
            heightCm: nil,
            weightKg: nil,
            avatarEmoji: nil,
            avatarImageData: nil
        )
    }
}

@MainActor
final class BabyProfileStore: Observable {
    static let shared = BabyProfileStore()

    var profile: BabyProfileData? {
        get {
            access(keyPath: \.profile)
            return _profile
        }
        set {
            withMutation(keyPath: \.profile) {
                _profile = newValue.map { Self.sanitized($0) }
                save()
            }
        }
    }

    private let _$observationRegistrar = ObservationRegistrar()
    private var _profile: BabyProfileData?
    private let key = "baby_profile"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode(BabyProfileData.self, from: data) {
            _profile = Self.sanitized(decoded)
        } else if let data = UserDefaults.standard.data(forKey: key),
                  data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
                  let decoded = try? JSONDecoder().decode(BabyProfile.self, from: data) {
            _profile = Self.sanitized(decoded.data)
        } else {
            _profile = Self.defaultProfile
        }
        save()
    }

    nonisolated func access<Member>(keyPath: KeyPath<BabyProfileStore, Member>) {
        _$observationRegistrar.access(self, keyPath: keyPath)
    }

    nonisolated func withMutation<Member, MutationResult>(
        keyPath: KeyPath<BabyProfileStore, Member>,
        _ mutation: () throws -> MutationResult
    ) rethrows -> MutationResult {
        try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
    }

    var currentProfile: BabyProfileData {
        profile ?? Self.defaultProfile
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
        syncToAppGroup(currentProfile)
        FamilyCloudStore.shared.scheduleUpload(reason: "profile")
    }

    func updateName(_ name: String) {
        var updated = currentProfile
        updated.name = name
        profile = updated
    }

    func updateGender(_ gender: BabyGender) {
        var updated = currentProfile
        updated.gender = gender
        profile = updated
    }

    func updateBirthDate(_ birthDate: Date) {
        var updated = currentProfile
        updated.birthDate = birthDate
        profile = updated
    }

    func updateBodyMetrics(heightCm: Double?, weightKg: Double?) {
        var updated = currentProfile
        updated.heightCm = heightCm
        updated.weightKg = weightKg
        profile = updated
    }

    func updateAvatar(_ avatarEmoji: String?) {
        var updated = currentProfile
        updated.rememberCurrentAvatar()
        updated.avatarEmoji = avatarEmoji
        updated.avatarImageData = nil
        updated.avatarCompanionID = nil
        updated.avatarVideoFilename = nil
        profile = updated
    }

    func updateAvatarImageData(_ imageData: Data?) {
        var updated = currentProfile
        updated.rememberCurrentAvatar()
        updated.avatarImageData = imageData
        if imageData != nil {
            updated.avatarEmoji = nil
            updated.avatarCompanionID = nil
            updated.avatarVideoFilename = nil
        }
        profile = updated
    }

    func updateAvatarCompanion(_ companionID: String?) {
        var updated = currentProfile
        updated.rememberCurrentAvatar()
        updated.avatarCompanionID = companionID
        if companionID != nil {
            updated.avatarEmoji = nil
            updated.avatarImageData = nil
            updated.avatarVideoFilename = nil
        }
        profile = updated
    }

    func updateAvatarVideo(filename: String?) {
        var updated = currentProfile
        updated.rememberCurrentAvatar()
        updated.avatarVideoFilename = filename
        if filename != nil {
            updated.avatarEmoji = nil
            updated.avatarImageData = nil
            updated.avatarCompanionID = nil
        }
        profile = updated
    }

    func create(
        name: String,
        gender: BabyGender,
        birthDate: Date,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        avatarEmoji: String? = nil,
        avatarImageData: Data? = nil,
        avatarCompanionID: String? = nil,
        avatarVideoFilename: String? = nil,
        avatarHistory: [BabyAvatarSnapshot]? = nil,
        avatarMotionEnabled: Bool? = nil
    ) {
        profile = BabyProfileData(
            name: name,
            gender: gender,
            birthDate: birthDate,
            heightCm: heightCm,
            weightKg: weightKg,
            avatarEmoji: avatarEmoji,
            avatarImageData: avatarImageData,
            avatarCompanionID: avatarCompanionID,
            avatarVideoFilename: avatarVideoFilename,
            avatarHistory: avatarHistory?.prefix(8).map { $0 },
            avatarMotionEnabled: avatarMotionEnabled
        )
    }

    func importProfile(_ profileData: BabyProfileData) {
        profile = profileData
    }

    var isOnboarded: Bool {
        guard let profile else { return false }
        return !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func syncToAppGroup(_ profileData: BabyProfileData) {
        guard let defaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID),
              let data = try? JSONEncoder().encode(profileData.widgetInfo()) else {
            return
        }
        defaults.set(data, forKey: WidgetStorageKey.babyInfo)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorageKey.lastFeedingWidgetKind)
        #endif
        let ageMonths = profileData.ageMonths
        Task { @MainActor in
            CareRecencyCoordinator.refreshFromSharedStorage(babyAgeMonths: ageMonths)
        }
    }

    private static func sanitized(_ input: BabyProfileData, now: Date = Date()) -> BabyProfileData {
        var value = input
        let cleanedName = value.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        value.name = String((cleanedName.isEmpty ? "宝宝" : cleanedName).prefix(40))
        value.birthDate = min(value.birthDate, now)
        value.heightCm = value.heightCm.flatMap { metric in
            metric.isFinite && GrowthMetricKind.height.validRange.contains(metric) ? metric : nil
        }
        value.weightKg = value.weightKg.flatMap { metric in
            metric.isFinite && GrowthMetricKind.weight.validRange.contains(metric) ? metric : nil
        }
        if let data = value.avatarImageData, data.count > BBBDataSafetyLimits.maxImageDataBytes {
            value.avatarImageData = nil
        }
        var remainingMediaBytes = BBBDataSafetyLimits.maxProfileMediaBytes
        if let data = value.avatarImageData {
            remainingMediaBytes = max(remainingMediaBytes - data.count, 0)
        }
        var boundedHistory: [BabyAvatarSnapshot] = []
        for var snapshot in value.avatarHistoryItems {
            guard boundedHistory.count < 8 else { break }
            if let data = snapshot.imageData {
                guard data.count <= BBBDataSafetyLimits.maxImageDataBytes,
                      data.count <= remainingMediaBytes else { continue }
                remainingMediaBytes -= data.count
            }
            snapshot.emoji = snapshot.emoji.map { String($0.prefix(32)) }
            snapshot.companionID = snapshot.companionID.map { String($0.prefix(128)) }
            snapshot.videoFilename = snapshot.videoFilename.map { String($0.prefix(255)) }
            boundedHistory.append(snapshot)
        }
        value.avatarHistory = boundedHistory
        return value
    }

    private static var defaultProfile: BabyProfileData {
        BabyProfileData(
            name: "宝宝",
            gender: .boy,
            birthDate: Calendar.current.date(byAdding: .day, value: -22, to: Date()) ?? Date(),
            heightCm: nil,
            weightKg: nil,
            avatarEmoji: nil,
            avatarImageData: nil
        )
    }
}

private extension BabyProfileData {
    mutating func rememberCurrentAvatar() {
        let snapshot = avatarSnapshot
        guard snapshot.isRenderable else { return }

        var items = avatarHistoryItems.filter { !$0.isSameAvatar(as: snapshot) }
        items.insert(snapshot, at: 0)
        avatarHistory = Array(items.prefix(8))
    }
}

// MARK: - Temperament

enum TemperamentDimension: String, Codable, CaseIterable, Identifiable {
    case activityLevel = "activity_level"
    case regularity
    case approach
    case adaptability
    case intensity
    case mood
    case attentionPersistence = "attention_persistence"
    case distractibility
    case sensorySensitivity = "sensory_sensitivity"

    var id: String { rawValue }
}

enum TemperamentType: String, Codable, CaseIterable, Identifiable {
    case easy
    case intermediate
    case slowToWarmUp = "slow_to_warm_up"
    case highSensitivity = "high_sensitivity"

    var id: String { rawValue }
}

struct BabyTemperamentResult: Codable, Hashable {
    var animalID: String
    var type: TemperamentType
    var scores: [TemperamentDimension: Double]
    var completedAt: Date
}

@MainActor
final class TemperamentProfileStore: ObservableObject {
    @Published private(set) var result: BabyTemperamentResult? {
        didSet {
            save()
            FamilyCloudStore.shared.scheduleUpload(reason: "temperament")
        }
    }

    private let key = "baby_temperament_result"

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
            let decoded = try? JSONDecoder().decode(BabyTemperamentResult.self, from: data)
        else { return }
        result = decoded
    }

    func update(_ result: BabyTemperamentResult) {
        self.result = result
    }

    func exportResult() -> BabyTemperamentResult? {
        result
    }

    func importResult(_ result: BabyTemperamentResult?) {
        self.result = result
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(result) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Feeding

enum FeedingType: String, Codable, CaseIterable {
    case breast
    case bottle
    case solid

    var displayName: String {
        switch self {
        case .breast: return "母乳（亲喂）"
        case .bottle: return "奶粉（瓶喂）"
        case .solid: return "辅食"
        }
    }

    var localizedDisplayName: String { displayName.localized }

    func localizedDisplayName(withMilkType milkType: MilkType?) -> String {
        displayName(withMilkType: milkType).localized
    }

    /// 根据瓶喂中的母乳/奶粉区分显示名
    func displayName(withMilkType milkType: MilkType?) -> String {
        switch self {
        case .breast: return "母乳（亲喂）"
        case .bottle:
            if milkType == .expressed { return "母乳（瓶喂）" }
            return "奶粉（瓶喂）"
        case .solid: return "辅食"
        }
    }

    var accent: Color {
        switch self {
        case .bottle: return DesignToken.feedingBottle
        case .breast: return DesignToken.feedingBreast
        case .solid: return DesignToken.feedingSolid
        }
    }
}

enum MilkType: String, Codable, CaseIterable, Identifiable {
    case expressed
    case formula

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expressed: return "母乳"
        case .formula: return "奶粉"
        }
    }

    var localizedDisplayName: String { displayName.localized }
}

enum BabyMood: String, Codable, CaseIterable {
    case happy = "😊"
    case neutral = "😐"
    case sad = "☹️"
}

enum BreastSide: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return "左"
        case .right: return "右"
        }
    }

    var localizedDisplayName: String { displayName.localized }
}

enum BreastFeedingMode: String, Codable, CaseIterable, Identifiable {
    case nursing
    case expressedBottle
    case pumping

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nursing: return "亲喂"
        case .expressedBottle: return "瓶喂母乳"
        case .pumping: return "吸乳"
        }
    }

    var localizedDisplayName: String { displayName.localized }

    var systemImage: String {
        switch self {
        case .nursing: return "heart.fill"
        case .expressedBottle: return "drop.fill"
        case .pumping: return "timer"
        }
    }
}

enum SolidUnit: String, Codable, CaseIterable, Identifiable {
    case g
    case oz
    case ml
    case mg
    case flOz = "fl_oz"
    case drop
    case piece
    case tsp
    case tbsp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .g: return "g"
        case .oz: return "oz"
        case .ml: return "ml"
        case .mg: return "mg"
        case .flOz: return "fl oz"
        case .drop: return "滴"
        case .piece: return "块"
        case .tsp: return "小勺"
        case .tbsp: return "大勺"
        }
    }

    var localizedDisplayName: String { displayName.localized }
}

enum SolidFood: String, Codable, CaseIterable, Identifiable {
    case rice
    case porridge
    case vegetable
    case fruit
    case meat
    case fish
    case egg
    case noodle
    case bread
    case yogurt
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rice: return "米糊"
        case .porridge: return "粥"
        case .vegetable: return "蔬菜"
        case .fruit: return "水果"
        case .meat: return "肉类"
        case .fish: return "鱼肉"
        case .egg: return "鸡蛋"
        case .noodle: return "面条"
        case .bread: return "面包"
        case .yogurt: return "酸奶"
        case .other: return "其他"
        }
    }

    var localizedDisplayName: String { displayName.localized }

    var emoji: String {
        switch self {
        case .rice: return "🍚"
        case .porridge: return "🥣"
        case .vegetable: return "🥬"
        case .fruit: return "🍎"
        case .meat: return "🥩"
        case .fish: return "🐟"
        case .egg: return "🥚"
        case .noodle: return "🍜"
        case .bread: return "🍞"
        case .yogurt: return "🥛"
        case .other: return "🍽️"
        }
    }

    var shortLabel: String {
        switch self {
        case .rice: return "米"
        case .porridge: return "粥"
        case .vegetable: return "蔬"
        case .fruit: return "果"
        case .meat: return "肉"
        case .fish: return "鱼"
        case .egg: return "蛋"
        case .noodle: return "面"
        case .bread: return "包"
        case .yogurt: return "奶"
        case .other: return "其"
        }
    }

    var suggestedUnit: SolidUnit {
        switch self {
        case .yogurt: return .ml
        default: return .g
        }
    }
}

struct FeedingEntry: Identifiable, Codable {
    let id: UUID
    var type: FeedingType
    var breastMode: BreastFeedingMode?
    var breastSide: BreastSide?
    var breastDuration: Int?
    var milkType: MilkType?
    var bottleAmount: Int?
    var bottleDuration: Int?
    var solidFood: SolidFood?
    var solidAmount: Double?
    var solidUnit: SolidUnit?

    init(
        id: UUID = UUID(),
        type: FeedingType,
        breastMode: BreastFeedingMode? = nil,
        breastSide: BreastSide? = nil,
        breastDuration: Int? = nil,
        milkType: MilkType? = nil,
        bottleAmount: Int? = nil,
        bottleDuration: Int? = nil,
        solidFood: SolidFood? = nil,
        solidAmount: Double? = nil,
        solidUnit: SolidUnit? = nil
    ) {
        self.id = id
        self.type = type
        self.breastMode = breastMode
        self.breastSide = breastSide
        self.breastDuration = breastDuration
        self.milkType = milkType
        self.bottleAmount = bottleAmount
        self.bottleDuration = bottleDuration
        self.solidFood = solidFood
        self.solidAmount = solidAmount
        self.solidUnit = solidUnit
    }

    func sanitized() -> FeedingEntry? {
        var value = self
        switch type {
        case .breast:
            guard let duration = breastDuration, duration > 0 else { return nil }
            value.breastDuration = min(duration, 240)
            value.bottleAmount = nil
            value.bottleDuration = nil
            value.solidAmount = nil
        case .bottle:
            guard let amount = bottleAmount, amount > 0 else { return nil }
            value.bottleAmount = min(amount, 2_000)
            value.bottleDuration = bottleDuration.flatMap { $0 > 0 ? min($0, 240) : nil }
            value.breastDuration = nil
            value.solidAmount = nil
        case .solid:
            guard let amount = solidAmount, amount.isFinite, amount > 0 else { return nil }
            value.solidAmount = min(amount, 2_000)
            value.breastDuration = nil
            value.bottleAmount = nil
            value.bottleDuration = nil
        }
        return value
    }
}

enum FeedingTimeSpanSource: String, Codable {
    case confirmed
    case recordedDuration
    case estimated
    case estimatedSkipped
    case point

    var isEstimated: Bool {
        self == .estimated || self == .estimatedSkipped
    }
}

struct FeedingResolvedTimeSpan {
    let startAt: Date
    let endAt: Date
    let source: FeedingTimeSpanSource

    var isPoint: Bool {
        endAt <= startAt
    }

    var isEstimated: Bool {
        source.isEstimated
    }
}

struct FeedingSession: Identifiable, Codable {
    let id: UUID
    var entries: [FeedingEntry]
    var notes: String
    var imageData: Data?
    var babyMood: BabyMood
    var createdAt: Date
    var startAt: Date?
    var endAt: Date?
    var timeSpanSource: FeedingTimeSpanSource?
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        entries: [FeedingEntry],
        notes: String = "",
        imageData: Data? = nil,
        babyMood: BabyMood = .happy,
        createdAt: Date = Date(),
        startAt: Date? = nil,
        endAt: Date? = nil,
        timeSpanSource: FeedingTimeSpanSource? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.entries = entries
        self.notes = notes
        self.imageData = imageData
        self.babyMood = babyMood
        self.createdAt = createdAt
        self.startAt = startAt
        self.endAt = endAt
        self.timeSpanSource = timeSpanSource
        self.updatedAt = updatedAt ?? Date()
    }

    init(
        id: UUID = UUID(),
        type: FeedingType,
        amountML: Int? = nil,
        durationMin: Int? = nil,
        solidsKind: String? = nil,
        solidsGram: Int? = nil,
        mood: BabyMood = .happy,
        note: String = "",
        createdAt: Date = Date(),
        startAt: Date? = nil,
        endAt: Date? = nil,
        timeSpanSource: FeedingTimeSpanSource? = nil,
        updatedAt: Date? = nil
    ) {
        let entry: FeedingEntry
        switch type {
        case .breast:
            entry = FeedingEntry(type: .breast, breastSide: .left, breastDuration: durationMin)
        case .bottle:
            entry = FeedingEntry(type: .bottle, milkType: .formula, bottleAmount: amountML)
        case .solid:
            let food = SolidFood.allCases.first { $0.displayName == solidsKind } ?? .rice
            entry = FeedingEntry(type: .solid, solidFood: food, solidAmount: solidsGram.map(Double.init), solidUnit: .g)
        }
        self.init(
            id: id,
            entries: [entry],
            notes: note,
            babyMood: mood,
            createdAt: createdAt,
            startAt: startAt,
            endAt: endAt,
            timeSpanSource: timeSpanSource,
            updatedAt: updatedAt
        )
    }

    var syncUpdatedAt: Date {
        updatedAt ?? createdAt
    }

    var type: FeedingType {
        entries.first?.type ?? .bottle
    }

    /// The time used to place this record on a day or timeline. Timed feedings
    /// belong to the day they started; point-in-time records use `createdAt`.
    var eventDate: Date {
        startAt ?? createdAt
    }

    /// Moves an existing record to a new timeline time without discarding its
    /// confirmed interval. If the preserved duration would extend into the
    /// future, the end is capped at the current time.
    func movingEventDate(to newEventDate: Date, referenceDate: Date = Date()) -> FeedingSession {
        var value = self
        let movedStart = min(newEventDate, referenceDate)

        if let startAt, let endAt, startAt <= endAt {
            let duration = max(endAt.timeIntervalSince(startAt), 0)
            let movedEnd = min(movedStart.addingTimeInterval(duration), referenceDate)
            value.startAt = movedStart
            value.endAt = movedEnd
            value.createdAt = movedEnd
            value.timeSpanSource = timeSpanSource ?? .confirmed
        } else {
            value.createdAt = movedStart
            value.startAt = nil
            value.endAt = nil
            value.timeSpanSource = .point
        }

        return value
    }

    /// 瓶喂时的奶类型（用于区分母乳瓶喂/奶粉瓶喂）
    var bottleMilkType: MilkType? {
        entries.first(where: { $0.type == .bottle })?.milkType
    }

    /// 区分母乳亲喂/母乳瓶喂/奶粉瓶喂的显示名
    var displayName: String {
        type.displayName(withMilkType: bottleMilkType)
    }

    var amountML: Int? {
        entries.compactMap(\.bottleAmount).first
    }

    var durationMin: Int? {
        entries.compactMap(\.breastDuration).first
    }

    var bottleDurationMin: Int? {
        entries.compactMap(\.bottleDuration).first
    }

    var solidsKind: String? {
        entries.compactMap { $0.solidFood?.displayName }.first
    }

    var solidsGram: Int? {
        entries.compactMap { entry in
            guard let amount = entry.solidAmount, amount.isFinite else { return nil }
            return Int(min(max(amount, 0), 2_000))
        }.first
    }

    var mood: BabyMood { babyMood }
    var note: String { notes }

    var totalBreastDuration: Int {
        entries.compactMap(\.breastDuration)
            .filter { $0 > 0 }
            .reduce(0) { min($0 + min($1, 240), 1_440) }
    }

    var totalBottleAmount: Int {
        entries.compactMap(\.bottleAmount)
            .filter { $0 > 0 }
            .reduce(0) { min($0 + min($1, 2_000), 20_000) }
    }

    var totalBottleDuration: Int {
        entries.compactMap(\.bottleDuration)
            .filter { $0 > 0 }
            .reduce(0) { min($0 + min($1, 240), 1_440) }
    }

    var totalSolidAmount: Double {
        entries.compactMap(\.solidAmount)
            .filter { $0.isFinite && $0 > 0 }
            .reduce(0) { min($0 + min($1, 2_000), 20_000) }
    }

    var hasData: Bool {
        entries.contains { entry in
            switch entry.type {
            case .breast:
                return (entry.breastDuration ?? 0) > 0
            case .bottle:
                return (entry.bottleAmount ?? 0) > 0
            case .solid:
                return (entry.solidAmount ?? 0) > 0
            }
        }
    }

    func resolvedTimeSpan(ageMonths: Int?) -> FeedingResolvedTimeSpan {
        let resolvedEnd = endAt ?? createdAt

        if let startAt, let endAt, startAt < endAt {
            return FeedingResolvedTimeSpan(
                startAt: startAt,
                endAt: endAt,
                source: timeSpanSource ?? .confirmed
            )
        }

        if recordedDurationMinutes > 0 {
            let start = resolvedEnd.addingTimeInterval(TimeInterval(-recordedDurationMinutes * 60))
            return FeedingResolvedTimeSpan(startAt: start, endAt: resolvedEnd, source: .recordedDuration)
        }

        if let estimatedMinutes = estimatedDurationMinutes(ageMonths: ageMonths), estimatedMinutes > 0 {
            let start = resolvedEnd.addingTimeInterval(TimeInterval(-estimatedMinutes * 60))
            return FeedingResolvedTimeSpan(
                startAt: start,
                endAt: resolvedEnd,
                source: timeSpanSource?.isEstimated == true
                    ? (timeSpanSource ?? .estimated)
                    : .estimated
            )
        }

        return FeedingResolvedTimeSpan(startAt: resolvedEnd, endAt: resolvedEnd, source: .point)
    }

    func sanitized(referenceDate: Date = Date()) -> FeedingSession? {
        let latestAcceptedDate = referenceDate.addingTimeInterval(5 * 60)
        guard createdAt <= latestAcceptedDate else { return nil }

        var value = self
        value.createdAt = min(createdAt, referenceDate)
        value.entries = entries.prefix(64).compactMap { $0.sanitized() }
        guard !value.entries.isEmpty else { return nil }
        value.notes = String(
            notes
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(2_000)
        )
        if let imageData, imageData.count > 8 * 1_024 * 1_024 {
            value.imageData = nil
        }

        if let startAt, let endAt,
           startAt <= endAt,
           startAt <= referenceDate,
           endAt <= latestAcceptedDate,
           endAt.timeIntervalSince(startAt) <= 24 * 60 * 60 {
            let clampedEnd = min(endAt, referenceDate)
            if clampedEnd >= startAt {
                value.startAt = startAt
                value.endAt = clampedEnd
            } else {
                value.startAt = nil
                value.endAt = nil
                value.timeSpanSource = nil
            }
        } else {
            value.startAt = nil
            value.endAt = nil
            value.timeSpanSource = nil
        }
        return value
    }

    var recordedDurationMinutes: Int {
        totalBreastDuration + totalBottleDuration
    }

    func estimatedDurationMinutes(ageMonths: Int?) -> Int? {
        var estimated = 0

        for entry in entries {
            switch entry.type {
            case .breast:
                break
            case .bottle:
                guard let amount = entry.bottleAmount, amount > 0 else { break }
                let profile = Self.bottlePaceProfile(ageMonths: ageMonths)
                let rawMinutes = Int(ceil(Double(amount) / profile.mlPerMinute))
                estimated += min(max(rawMinutes, profile.minMinutes), profile.maxMinutes)
            case .solid:
                guard let amount = entry.solidAmount, amount.isFinite, amount > 0 else { break }
                let normalizedAmount = Self.normalizedSolidAmount(amount, unit: entry.solidUnit ?? .g)
                let rawMinutes = Int(ceil(normalizedAmount / 12.0))
                estimated += min(max(rawMinutes, 5), 20)
            }
        }

        return estimated > 0 ? min(estimated, 60) : nil
    }

    private static func bottlePaceProfile(ageMonths: Int?) -> (mlPerMinute: Double, minMinutes: Int, maxMinutes: Int) {
        let months = max(ageMonths ?? 3, 0)
        switch months {
        case 0:
            return (4, 8, 30)
        case 1..<3:
            return (6, 6, 25)
        case 3..<6:
            return (8, 5, 20)
        case 6..<12:
            return (10, 5, 18)
        default:
            return (12, 4, 15)
        }
    }

    private static func normalizedSolidAmount(_ amount: Double, unit: SolidUnit) -> Double {
        switch unit {
        case .g, .ml:
            return amount
        case .mg:
            return amount / 1000
        case .oz, .flOz:
            return amount * 30
        case .drop:
            return amount * 0.05
        case .piece:
            return amount * 10
        case .tsp:
            return amount * 5
        case .tbsp:
            return amount * 15
        }
    }
}

struct FeedingSummary {
    var date: Date
    var totalSessions: Int
    var breastCount: Int
    var breastDuration: Int
    var bottleCount: Int
    var bottleAmount: Int
    var solidCount: Int
    var solidAmount: Double
}

enum GrowthMetricKind: String, Codable, CaseIterable, Identifiable {
    case weight
    case height

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: return "体重".localized
        case .height: return "身高".localized
        }
    }

    var unit: String {
        switch self {
        case .weight: return "kg"
        case .height: return "cm"
        }
    }

    var accent: Color {
        switch self {
        case .weight: return DesignToken.primary
        case .height: return DesignToken.accentBlue
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .height: return "ruler.fill"
        }
    }

    var heroAssetName: String {
        switch self {
        case .weight: return "record_weight_scale_hero"
        case .height: return "record_height_meter_hero"
        }
    }

    var validRange: ClosedRange<Double> {
        switch self {
        case .weight: return 0.5...40
        case .height: return 30...130
        }
    }
}

struct GrowthMetricRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: GrowthMetricKind
    var value: Double
    var note: String
    var recordedAt: Date
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        kind: GrowthMetricKind,
        value: Double,
        note: String = "",
        recordedAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.value = value
        self.note = note
        self.recordedAt = recordedAt
        self.updatedAt = updatedAt ?? Date()
    }

    var unit: String { kind.unit }

    var syncUpdatedAt: Date {
        updatedAt ?? recordedAt
    }
}

@MainActor
final class GrowthMetricStore: ObservableObject {
    @Published private(set) var records: [GrowthMetricRecord] = [] {
        didSet {
            persist()
            FamilyCloudStore.shared.scheduleUpload(reason: "growth")
        }
    }

    private let key = "growth_metric_records_v1"

    init() {
        loadRecords()
        syncLatestProfileMetrics()
    }

    func saveRecord(kind: GrowthMetricKind, value: Double, note: String = "", recordedAt: Date = Date()) {
        guard value.isFinite, kind.validRange.contains(value), recordedAt <= Date() else { return }
        let cleanedNote = clean(note)
        records.append(GrowthMetricRecord(kind: kind, value: value, note: cleanedNote, recordedAt: recordedAt))
        records.sort { $0.recordedAt > $1.recordedAt }
        syncLatestProfileMetrics()
    }

    func updateRecord(_ record: GrowthMetricRecord, value: Double, note: String, recordedAt: Date) {
        guard value.isFinite, record.kind.validRange.contains(value), recordedAt <= Date() else { return }
        let updated = GrowthMetricRecord(
            id: record.id,
            kind: record.kind,
            value: value,
            note: clean(note),
            recordedAt: recordedAt
        )
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            records.append(updated)
            records.sort { $0.recordedAt > $1.recordedAt }
            syncLatestProfileMetrics()
            return
        }
        records[index] = updated
        records.sort { $0.recordedAt > $1.recordedAt }
        syncLatestProfileMetrics()
    }

    func deleteRecord(_ record: GrowthMetricRecord) {
        records.removeAll { $0.id == record.id }
        FamilyCloudStore.shared.markGrowthMetricRecordDeleted(record.id)
        syncLatestProfileMetrics()
    }

    func records(on date: Date) -> [GrowthMetricRecord] {
        records
            .filter { Calendar.current.isDate($0.recordedAt, inSameDayAs: date) }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func records(kind: GrowthMetricKind) -> [GrowthMetricRecord] {
        records
            .filter { $0.kind == kind }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func latest(kind: GrowthMetricKind) -> GrowthMetricRecord? {
        records(kind: kind).first
    }

    func previous(before record: GrowthMetricRecord) -> GrowthMetricRecord? {
        records(kind: record.kind).first {
            $0.id != record.id && $0.recordedAt < record.recordedAt
        }
    }

    func changeInLast30Days(kind: GrowthMetricKind, from date: Date = Date()) -> Double? {
        let kindRecords = records(kind: kind)
        guard let latest = kindRecords.first else { return nil }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: date) ?? date
        let baseline = kindRecords
            .filter { $0.recordedAt <= cutoff }
            .first ?? kindRecords.last
        guard let baseline else { return nil }
        return latest.value - baseline.value
    }

    func exportRecords() -> [GrowthMetricRecord] {
        records
    }

    func importRecords(_ records: [GrowthMetricRecord]) {
        let now = Date()
        self.records = Array(records.prefix(BBBDataSafetyLimits.maxGrowthMetricRecords))
            .filter { $0.value.isFinite && $0.kind.validRange.contains($0.value) && $0.recordedAt <= now }
            .sorted { $0.recordedAt > $1.recordedAt }
        syncLatestProfileMetrics()
    }

    private func loadRecords() {
        let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        guard let data = UserDefaults.standard.data(forKey: key)
                ?? appGroupDefaults?.data(forKey: key),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
              let decoded = try? JSONDecoder().decode([GrowthMetricRecord].self, from: data) else {
            return
        }
        let now = Date()
        records = Array(decoded.prefix(BBBDataSafetyLimits.maxGrowthMetricRecords))
            .filter { $0.value.isFinite && $0.kind.validRange.contains($0.value) && $0.recordedAt <= now }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.set(data, forKey: key)
    }

    private func syncLatestProfileMetrics() {
        let profileStore = BabyProfileStore.shared
        let latestHeight = latest(kind: .height)?.value
        let latestWeight = latest(kind: .weight)?.value
        profileStore.updateBodyMetrics(heightCm: latestHeight, weightKg: latestWeight)
    }

    private func clean(_ note: String) -> String {
        note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }
}

@MainActor
final class FeedingStore: ObservableObject {
    @Published var sessions: [FeedingSession] = [] {
        didSet {
            persist()
            FamilyCloudStore.shared.scheduleUpload(reason: "feeding")
        }
    }

    private let key = "feeding_sessions_v2"

    init() {
        if
            let data = Self.loadInitialData(key: key),
            let decoded = try? JSONDecoder().decode([FeedingSession].self, from: data)
        {
            let now = Date()
            sessions = Array(
                decoded
                    .prefix(BBBDataSafetyLimits.maxFeedingSessions)
                    .compactMap { $0.sanitized(referenceDate: now) }
                    .sorted { $0.eventDate > $1.eventDate }
                    .prefix(BBBDataSafetyLimits.maxFeedingSessions)
            )
        } else {
            sessions = []
        }
    }

    var todaySessions: [FeedingSession] {
        sessions(on: Date())
    }

    var allSessions: [FeedingSession] {
        sessions
    }

    func sessions(on date: Date) -> [FeedingSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.eventDate, inSameDayAs: date) }
            .sorted { $0.eventDate > $1.eventDate }
    }

    func feedCount(on date: Date) -> Int {
        sessions(on: date).count
    }

    func breastDuration(on date: Date) -> Int {
        sessions(on: date).reduce(0) { total, session in
            total + session.totalBreastDuration
        }
    }

    func formulaML(on date: Date) -> Int {
        sessions(on: date).reduce(0) { total, session in
            total + session.entries
                .filter { $0.type == .bottle && ($0.milkType ?? .formula) == .formula }
                .compactMap(\.bottleAmount)
                .reduce(0, +)
        }
    }

    func solidsGram(on date: Date) -> Int {
        sessions(on: date).reduce(0) { total, session in
            total + session.entries
                .filter { $0.type == .solid }
                .compactMap { entry in
                    guard let amount = entry.solidAmount, amount.isFinite else { return nil }
                    return Int(min(max(amount, 0), 2_000))
                }
                .reduce(0, +)
        }
    }

    var feedCountToday: Int { feedCount(on: Date()) }

    var breastCount: Int {
        sessionCount(in: todaySessions) { $0.type == .breast }
    }

    var breastDuration: Int {
        breastDuration(on: Date())
    }

    var formulaCount: Int {
        sessionCount(in: todaySessions) { $0.type == .bottle && ($0.milkType ?? .formula) == .formula }
    }

    var formulaML: Int {
        formulaML(on: Date())
    }

    var expressedMilkCount: Int {
        sessionCount(in: todaySessions) { $0.type == .bottle && $0.milkType == .expressed }
    }

    var expressedMilkML: Int {
        todaySessions.reduce(0) { total, session in
            total + session.entries
                .filter { $0.type == .bottle && $0.milkType == .expressed }
                .compactMap(\.bottleAmount)
                .reduce(0, +)
        }
    }

    var solidsCount: Int {
        sessionCount(in: todaySessions) { $0.type == .solid }
    }

    var solidsGram: Int {
        solidsGram(on: Date())
    }

    func add(_ session: FeedingSession) {
        saveSession(session)
    }

    func saveSession(_ session: FeedingSession) {
        guard let sanitized = session.sanitized(),
              !sessions.contains(where: { $0.id == sanitized.id }) else { return }
        sessions = (sessions + [sanitized]).sorted { $0.eventDate > $1.eventDate }
        EasyCycleStore.shared.trackFeedingSession(sanitized)
    }

    func deleteSession(_ session: FeedingSession) {
        sessions.removeAll { $0.id == session.id }
        EasyCycleStore.shared.removeRecordLink(type: .feeding, recordID: session.id)
        SubjectiveStateStore.shared.deleteLinked(sourceType: .feeding, sourceRecordID: session.id)
        FamilyCloudStore.shared.markFeedingSessionDeleted(session.id)
    }

    func updateSession(_ session: FeedingSession) {
        guard var sanitized = session.sanitized() else { return }
        // Editing a legacy record may start with a nil revision clock. Refresh
        // it here, at the write boundary, without changing import/sort paths.
        sanitized.updatedAt = Date()
        guard let index = sessions.firstIndex(where: { $0.id == sanitized.id }) else {
            saveSession(sanitized)
            return
        }
        var updatedSessions = sessions
        updatedSessions[index] = sanitized
        sessions = updatedSessions.sorted { $0.eventDate > $1.eventDate }
        EasyCycleStore.shared.removeRecordLink(type: .feeding, recordID: sanitized.id)
        EasyCycleStore.shared.trackFeedingSession(sanitized)
        SubjectiveStateStore.shared.updateLinkedRecord(
            sourceType: .feeding,
            sourceRecordID: sanitized.id,
            recordedAt: sanitized.eventDate
        )
    }

    func exportSessions() -> [FeedingSession] {
        sessions
    }

    func importSessions(_ sessions: [FeedingSession]) {
        let now = Date()
        self.sessions = Array(
            sessions
                .prefix(BBBDataSafetyLimits.maxFeedingSessions)
                .compactMap { $0.sanitized(referenceDate: now) }
                .sorted { $0.eventDate > $1.eventDate }
                .prefix(BBBDataSafetyLimits.maxFeedingSessions)
        )
    }

    func todaySummary(for date: Date = Date()) -> FeedingSummary {
        let calendar = Calendar.current
        let daySessions = sessions.filter { calendar.isDate($0.eventDate, inSameDayAs: date) }
        return FeedingSummary(
            date: date,
            totalSessions: daySessions.count,
            breastCount: sessionCount(in: daySessions) { $0.type == .breast },
            breastDuration: daySessions.map(\.totalBreastDuration).reduce(0, +),
            bottleCount: sessionCount(in: daySessions) { $0.type == .bottle },
            bottleAmount: daySessions.map(\.totalBottleAmount).reduce(0, +),
            solidCount: sessionCount(in: daySessions) { $0.type == .solid },
            solidAmount: daySessions.map(\.totalSolidAmount).reduce(0, +)
        )
    }

    private func sessionCount(in sessions: [FeedingSession], where matches: (FeedingEntry) -> Bool) -> Int {
        sessions.filter { session in
            session.entries.contains(where: matches)
        }.count
    }

    func lastFeedingTime(relativeTo referenceDate: Date = Date()) -> Date? {
        CareRecencyCalculator.snapshot(
            feedingSessions: sessions,
            careRecords: [],
            referenceDate: referenceDate
        ).feeding.completedAt
    }

    nonisolated static func sharedLastFeedingTime() -> Date? {
        let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        let data = appGroupDefaults?.data(forKey: WidgetStorageKey.feedingSessions)
            ?? appGroupDefaults?.data(forKey: "feeding_sessions_v2")
            ?? UserDefaults.standard.data(forKey: "feeding_sessions_v2")
        guard
            let data,
            data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
            let sessions = try? JSONDecoder().decode([FeedingSession].self, from: data)
        else {
            return nil
        }
        return CareRecencyCalculator.snapshot(
            feedingSessions: Array(sessions.prefix(BBBDataSafetyLimits.maxFeedingSessions)),
            careRecords: [],
            referenceDate: Date()
        ).feeding.completedAt
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
            let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
            appGroupDefaults?.set(data, forKey: key)
            appGroupDefaults?.set(data, forKey: WidgetStorageKey.feedingSessions)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorageKey.lastFeedingWidgetKind)
            #endif
        }
        CareRecencyCoordinator.refreshFromSharedStorage(
            babyAgeMonths: BabyProfileStore.shared.currentProfile.ageMonths
        )
    }

    private static func loadInitialData(key: String) -> Data? {
        let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        if let data = appGroupDefaults?.data(forKey: key) ?? appGroupDefaults?.data(forKey: WidgetStorageKey.feedingSessions) {
            guard data.count <= BBBDataSafetyLimits.maxJSONDataBytes else { return nil }
            if UserDefaults.standard.data(forKey: key) == nil {
                UserDefaults.standard.set(data, forKey: key)
            }
            return data
        }
        if let data = UserDefaults.standard.data(forKey: key) {
            guard data.count <= BBBDataSafetyLimits.maxJSONDataBytes else { return nil }
            appGroupDefaults?.set(data, forKey: key)
            appGroupDefaults?.set(data, forKey: WidgetStorageKey.feedingSessions)
            return data
        }
        return nil
    }

}
