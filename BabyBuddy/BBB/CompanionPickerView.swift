import SwiftUI
import UIKit
import CoreMotion

/// Fixed pigments used only to render the Buddy card's illustrative fallback.
/// They are intentionally independent of the interface appearance palette.
private enum CompanionRenderPalette {
    static func pigment(_ hex: String) -> Color {
        Color(hex: hex) // color-audit: allow-fixed companion illustration pigment
    }
}

struct BuddyCardTilt: Equatable {
    var x: CGFloat
    var y: CGFloat

    static let zero = BuddyCardTilt(x: 0, y: 0)
}

final class BuddyCardMotionModel: ObservableObject {
    @Published var tilt: BuddyCardTilt = .zero

    private let manager = CMMotionManager()
    private var isRunning = false

    func start(enabled: Bool) {
        guard enabled, manager.isDeviceMotionAvailable else {
            stop()
            return
        }
        guard !isRunning else { return }

        isRunning = true
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let roll = max(min(motion.attitude.roll, 0.42), -0.42)
            let pitch = max(min(motion.attitude.pitch, 0.42), -0.42)
            withAnimation(.easeOut(duration: 0.10)) {
                self.tilt = BuddyCardTilt(
                    x: CGFloat(roll / 0.42),
                    y: CGFloat(pitch / 0.42)
                )
            }
        }
    }

    func stop() {
        guard isRunning || tilt != .zero else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
        withAnimation(.easeOut(duration: 0.16)) {
            tilt = .zero
        }
    }
}

struct BuddyCardSurface: View {
    let tint: Color
    let tilt: BuddyCardTilt
    let isHolographic: Bool
    let reducedEffects: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignToken.glassFill.opacity(0.88),
                                tint.opacity(0.12),
                                DesignToken.glassFill.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(cardTexture.clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous)))
            .overlay {
                if isHolographic && !reducedEffects {
                    holographicWash
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(tint.opacity(0.32), lineWidth: 1.2)
            )
            .shadow(color: tint.opacity(0.14), radius: reducedEffects ? 18 : 28, y: reducedEffects ? 10 : 16)
    }

    private var cardTexture: some View {
        GeometryReader { proxy in
            let columns = max(Int(proxy.size.width / 12), 1)
            let rows = max(Int(proxy.size.height / 12), 1)

            Canvas { context, _ in
                for row in 0..<rows {
                    for column in 0..<columns where (row + column).isMultiple(of: 3) {
                        let rect = CGRect(x: CGFloat(column) * 12, y: CGFloat(row) * 12, width: 1.5, height: 1.5)
                        context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.06)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var holographicWash: some View {
        GeometryReader { proxy in
            let centerX = min(max(0.5 + tilt.x * 0.24, 0.12), 0.88)
            let centerY = min(max(0.5 - tilt.y * 0.20, 0.16), 0.84)
            let diagonalStart = UnitPoint(x: min(max(0.05 + tilt.x * 0.16, 0), 1), y: 0)
            let diagonalEnd = UnitPoint(x: min(max(0.95 + tilt.x * 0.16, 0), 1), y: 1)

            ZStack {
                LinearGradient(
                    colors: [
                        .clear,
                        CompanionRenderPalette.pigment("#9EE7FF").opacity(0.18),
                        CompanionRenderPalette.pigment("#FFF0A8").opacity(0.22),
                        CompanionRenderPalette.pigment("#E9B7FF").opacity(0.18),
                        .clear
                    ],
                    startPoint: diagonalStart,
                    endPoint: diagonalEnd
                )
                .opacity(0.95)

                RadialGradient(
                    colors: [
                        DesignToken.glassFill.opacity(0.26),
                        tint.opacity(0.18),
                        .clear
                    ],
                    center: UnitPoint(x: centerX, y: centerY),
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.72
                )
            }
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }
}

private struct BuddyCardTiltModifier: ViewModifier {
    let tilt: BuddyCardTilt
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(enabled ? Double(-tilt.y) * 2.2 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.72)
            .rotation3DEffect(.degrees(enabled ? Double(tilt.x) * 2.4 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
            .offset(x: enabled ? tilt.x * 2.5 : 0, y: enabled ? -tilt.y * 1.8 : 0)
    }
}

extension View {
    func buddyCardTiltEffect(_ tilt: BuddyCardTilt, enabled: Bool) -> some View {
        modifier(BuddyCardTiltModifier(tilt: tilt, enabled: enabled))
    }
}

struct CompanionPickerView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @Binding var isPresented: Bool
    var showsCloseButton = true
    var dismissesOnSelection = true
    var bottomContentPadding: CGFloat = 42

    @State private var selectedCompanion: BabyCompanion?

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 10),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
        )
    }

    var body: some View {
        ZStack {
            pickerBackground

            VStack(spacing: DesignToken.contentSpacing) {
                topBar

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                        ForEach(BabyCompanion.all) { companion in
                            companionGridButton(companion)
                        }
                    }
                    .padding(.horizontal, DesignToken.screenHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, bottomContentPadding)
                }
            }
        }
        .overlay {
            if let selectedCompanion {
                companionDetailOverlay(selectedCompanion)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedCompanion?.id)
        .accessibilityIdentifier("buddy.grid.screen")
    }

    private var pickerBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignToken.canvas,
                    DesignToken.surfaceSoft,
                    DesignToken.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    DesignToken.glassFill.opacity(0.70),
                    DesignToken.glassFill.opacity(0.0)
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 14) {
            if showsCloseButton {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
                        .background(
                            Circle()
                                .fill(DesignToken.surfaceRaised.opacity(0.92))
                                .shadow(color: DesignToken.shadowColor.opacity(0.16), radius: 12, y: 5)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("BBBuddy")
                    .font(BBBFont.scaledFont(size: 20, weight: .bold, relativeTo: .title2, maximumPointSize: 30))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignToken.primary, DesignToken.textStrong],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                .accessibilityLabel("BBBuddy")

                Text("选择今天陪伴宝宝的伙伴")
                    .font(BBBFont.scaledFont(size: 11, weight: .semibold, relativeTo: .subheadline, maximumPointSize: 18))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, DesignToken.screenHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    private func companionGridButton(_ companion: BabyCompanion) -> some View {
        let isUnlocked = isCompanionUnlocked(companion)
        let isCurrent = companionStore.selectedID == companion.id

        return Button {
            selectedCompanion = companion
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    CompanionAnimalFigure(
                        companion: companion,
                        isUnlocked: isUnlocked,
                        size: isUnlocked ? 62 : 68
                    )
                    .frame(width: 76, height: 76, alignment: .center)

                    if isCurrent, isUnlocked {
                        Text("当前")
                            .font(BBBFont.font(size: 8, weight: .heavy))
                            .foregroundStyle(DesignToken.onPrimary)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(Capsule().fill(DesignToken.primaryGradient))
                            .offset(x: 1, y: 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 82)

                VStack(spacing: 3) {
                    Text(isUnlocked ? companion.localizedName : "未解锁")
                        .font(BBBFont.scaledFont(size: 12, weight: .bold, relativeTo: .headline, maximumPointSize: 19))
                        .foregroundStyle(isUnlocked ? DesignToken.textPrimary : DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if isUnlocked {
                        Text(companion.localizedSpecies)
                            .font(BBBFont.scaledFont(size: 8, weight: .semibold, relativeTo: .caption2, maximumPointSize: 14))
                            .foregroundStyle(DesignToken.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 36 : 22, alignment: .top)
                    } else {
                        CompanionFriendshipHearts(
                            companion: companion,
                            friendshipValue: recruitmentStore.friendshipValue(for: companion.id),
                            isUnlocked: false,
                            size: 8
                        )
                    }
                }
            }
            .padding(.horizontal, 7)
            .padding(.top, 13)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 190 : 154, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: DesignToken.mediumCardRadius, style: .continuous)
                    .fill(DesignToken.surfaceRaised.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignToken.mediumCardRadius, style: .continuous)
                            .stroke(DesignToken.glassStroke.opacity(0.92), lineWidth: 1)
                    )
                    .shadow(color: DesignToken.softShadow.opacity(0.75), radius: 10, y: 5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isUnlocked ? "\(companion.localizedName), \(companion.localizedSpecies)" : "未获取伙伴")
    }

    private func companionDetailOverlay(_ companion: BabyCompanion) -> some View {
        CompanionDetailOverlay(
            companion: companion,
            selectedCompanion: $selectedCompanion
        ) {
            if dismissesOnSelection {
                isPresented = false
            }
        }
    }

    private func isCompanionUnlocked(_ companion: BabyCompanion) -> Bool {
        recruitmentStore.isUnlocked(
            companion,
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID
        )
    }

}

struct CompanionDetailOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @AppStorage("buddy_card_reduced_effects_enabled") private var reducedBuddyCardEffects = false
    @StateObject private var buddyCardMotion = BuddyCardMotionModel()
    let companion: BabyCompanion
    @Binding var selectedCompanion: BabyCompanion?
    var onSetCurrent: () -> Void = {}

    var body: some View {
        let displayCompanion = selectedCompanion ?? companion
        let isUnlocked = isCompanionUnlocked(displayCompanion)
        let style = rarityStyle(for: displayCompanion.rarity)
        let backdrop = backdropStyle(for: displayCompanion)

        return ZStack {
            modalBackdrop(body: backdrop.body, accent: backdrop.accent)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCompanion = nil
                }

            GeometryReader { proxy in
                let bottomPadding = max(proxy.safeAreaInsets.bottom + 128, 150)

                VStack(spacing: 10) {
                    Spacer(minLength: 0)

                    buddyCard(companion: displayCompanion, isUnlocked: isUnlocked, style: style)
                        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .gesture(cardSwipeGesture)
                        .onTapGesture {}

                    carouselIndicator(for: displayCompanion, tint: backdrop.accent)
                        .padding(.top, 2)
                        .onTapGesture {}

                    if isUnlocked {
                        currentCompanionControl(displayCompanion, tint: backdrop.accent)
                            .onTapGesture {}
                    } else {
                        lockedRelationshipControl(displayCompanion)
                            .onTapGesture {}
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, proxy.safeAreaInsets.top + 18)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .onAppear(perform: refreshBuddyCardMotion)
        .onDisappear {
            buddyCardMotion.stop()
        }
        .onChange(of: reducedBuddyCardEffects) { _, _ in
            refreshBuddyCardMotion()
        }
        .onChange(of: reduceMotion) { _, _ in
            refreshBuddyCardMotion()
        }
    }

    private func modalBackdrop(body: Color, accent: Color) -> some View {
        Rectangle()
            .fill(.thickMaterial)
            .overlay(
                LinearGradient(
                    colors: [
                        body.opacity(0.24),
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

    private func buddyCard(
        companion: BabyCompanion,
        isUnlocked: Bool,
        style: (tint: Color, text: Color)
    ) -> some View {
        let tilt = activeBuddyCardTilt
        let temperamentStyle = companion.temperamentStyle

        return VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 9) {
                    Text(companion.catalogNumber)
                        .font(BBBFont.font(size: 10, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                        .tracking(2)

                    Rectangle()
                        .fill(DesignToken.textSecondary.opacity(0.22))
                        .frame(width: 1, height: 13)

                    Text(companion.rarity.title.localized)
                        .font(BBBFont.font(size: 9, weight: .heavy))
                        .foregroundStyle(style.text)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(style.tint.opacity(0.18)))

                    temperamentChip(companion.localizedTemperamentLabel, tint: temperamentStyle.tint, text: temperamentStyle.text)
                }

                Spacer()

                CompanionFriendshipHearts(
                    companion: companion,
                    friendshipValue: recruitmentStore.friendshipValue(for: companion.id),
                    isUnlocked: isUnlocked,
                    size: 14,
                    filledColor: DesignToken.easyActivity,
                    emptyColor: DesignToken.borderSubtle.opacity(0.62)
                )
            }

            ZStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isUnlocked ? companion.localizedName : "未解锁")
                        .font(BBBFont.font(size: 34, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text(isUnlocked ? companion.englishName : "Keep caring")
                        .font(BBBFont.font(size: 15, weight: .regular))
                        .foregroundStyle(DesignToken.textSecondary)
                        .tracking(0.4)

                    Text(isUnlocked ? companion.localizedSpecies : "等待相遇")
                        .font(BBBFont.font(size: 9, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.86))
                        .tracking(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer()
                }
                .padding(.top, 22)
                .frame(maxWidth: 172, alignment: .leading)
                .zIndex(2)

                CompanionAnimalFigure(
                    companion: companion,
                    isUnlocked: isUnlocked,
                    size: 238
                )
                .frame(maxWidth: .infinity, minHeight: 278, alignment: .trailing)
                .offset(x: 7 + tilt.x * 7, y: 5 - tilt.y * 5)
                .shadow(color: style.tint.opacity(isUnlocked ? 0.20 : 0.08), radius: 22, y: 14)
            }
            .frame(height: 286)

            VStack(alignment: .leading, spacing: 10) {
                Text(isUnlocked ? companion.localizedIntro : "友情值 \(recruitmentStore.friendshipValue(for: companion.id))/\(companion.friendshipTarget)，继续准备小点心，等它慢慢靠近。")
                    .font(BBBFont.font(size: 10, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                distributionRow(isUnlocked ? companion.localizedWorldDistribution : "在每日来访中培养友情，满值后解锁伙伴卡。")
            }
            .padding(.top, 13)
            .padding(.bottom, 2)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DesignToken.glassStroke.opacity(0.55))
                    .frame(height: 1)
            }
        }
        .padding(16)
        .background(
            BuddyCardSurface(
                tint: style.tint,
                tilt: tilt,
                isHolographic: shouldUseHolographic(for: companion.rarity),
                reducedEffects: reducedBuddyCardEffects || reduceMotion
            )
        )
        .buddyCardTiltEffect(tilt, enabled: isBuddyCardMotionEnabled)
    }

    private var cardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical), abs(horizontal) > 42 else { return }

                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    moveSelectedCompanion(by: horizontal < 0 ? 1 : -1)
                }
            }
    }

    private func moveSelectedCompanion(by offset: Int) {
        let companions = BabyCompanion.all
        guard let current = selectedCompanion ?? companions.first,
              let index = companions.firstIndex(where: { $0.id == current.id }) else {
            selectedCompanion = companions.first
            return
        }

        let nextIndex = (index + offset + companions.count) % companions.count
        selectedCompanion = companions[nextIndex]
    }

    private func carouselIndicator(for companion: BabyCompanion, tint: Color) -> some View {
        let total = BabyCompanion.all.count
        let index = BabyCompanion.all.firstIndex(where: { $0.id == companion.id }) ?? 0
        let progress = total > 1 ? Double(index) / Double(total - 1) : 0

        return HStack(spacing: 9) {
            Image(systemName: "chevron.left")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.46))

            GeometryReader { proxy in
                let thumbWidth: CGFloat = 18
                let trackWidth = max(proxy.size.width, thumbWidth)
                let x = CGFloat(progress) * max(trackWidth - thumbWidth, 0)

                Capsule()
                    .fill(DesignToken.surfaceRaised.opacity(0.48))
                    .overlay(
                        Capsule()
                            .stroke(DesignToken.glassStroke.opacity(0.70), lineWidth: 1)
                    )
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint.opacity(0.54))
                            .frame(width: thumbWidth, height: 5)
                            .offset(x: x)
                    }
            }
            .frame(width: 82, height: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.46))
        }
        .frame(height: 22)
        .accessibilityLabel("伙伴卡 \(index + 1) / \(total)")
    }

    private func currentCompanionControl(_ companion: BabyCompanion, tint: Color) -> some View {
        let isCurrent = companionStore.selectedID == companion.id

        return Group {
            if isCurrent {
                Text("当前伙伴")
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: DesignToken.minimumTapSize)
                    .background(
                        Capsule()
                            .fill(DesignToken.surfaceRaised.opacity(0.52))
                            .overlay(Capsule().stroke(DesignToken.glassStroke.opacity(0.74), lineWidth: 1))
                    )
            } else {
                Button {
                    companionStore.selectedID = companion.id
                    selectedCompanion = nil
                    onSetCurrent()
                } label: {
                    Text("切换为这个伙伴")
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(tint.opacity(0.86))
                        .padding(.horizontal, 18)
                        .frame(minHeight: DesignToken.minimumTapSize)
                        .background(
                            Capsule()
                                .fill(DesignToken.surfaceRaised.opacity(0.50))
                                .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 1))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func lockedRelationshipControl(_ companion: BabyCompanion) -> some View {
        let queue = recruitmentStore.relationshipState.wishQueueIDs
        let queueIndex = queue.firstIndex(of: companion.id)
        let isActive = recruitmentStore.relationshipState.activeCompanionID == companion.id

        return HStack(spacing: 8) {
            if isActive {
                Label("正在认识 · 明天还会来", systemImage: "calendar.badge.checkmark")
                    .font(BBBFont.font(size: 10.5, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
            } else if let queueIndex {
                Text("愿望队列第 \(queueIndex + 1) 位")
                    .font(BBBFont.font(size: 10.5, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                Spacer()
                Button {
                    moveQueueItem(companion.id, offset: -1)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(queueIndex == 0)
                Button {
                    moveQueueItem(companion.id, offset: 1)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .disabled(queueIndex == queue.count - 1)
                Button("移除") {
                    recruitmentStore.setWishQueue(
                        queue.filter { $0 != companion.id },
                        isPlusActive: membershipStore.isPlusActive
                    )
                }
            } else if membershipStore.isPlusActive {
                Text(queue.count < 3 ? "加入愿望队列，当前 \(queue.count)/3" : "愿望队列已满 3/3")
                    .font(BBBFont.font(size: 10.5, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                Spacer()
                Button("加入") {
                    recruitmentStore.setWishQueue(
                        queue + [companion.id],
                        isPlusActive: membershipStore.isPlusActive
                    )
                }
                .font(BBBFont.font(size: 10.5, weight: .heavy))
                .disabled(queue.count >= 3)
            } else {
                Text("每日来访中招待后，可邀请这位 Buddy 明天再来。")
                    .font(BBBFont.font(size: 10, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.78))
            }
        }
        .foregroundStyle(DesignToken.primary)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Capsule().fill(DesignToken.surfaceRaised.opacity(0.76)))
        .padding(.horizontal, 28)
    }

    private func moveQueueItem(_ companionID: String, offset: Int) {
        var queue = recruitmentStore.relationshipState.wishQueueIDs
        guard let index = queue.firstIndex(of: companionID) else { return }
        let destination = min(max(index + offset, 0), queue.count - 1)
        guard destination != index else { return }
        queue.swapAt(index, destination)
        recruitmentStore.setWishQueue(queue, isPlusActive: membershipStore.isPlusActive)
    }

    private func isCompanionUnlocked(_ companion: BabyCompanion) -> Bool {
        recruitmentStore.isUnlocked(
            companion,
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID
        )
    }

    private func temperamentChip(_ title: String, tint: Color, text: Color) -> some View {
        Text(title.localized)
            .font(BBBFont.font(size: 9, weight: .heavy))
            .foregroundStyle(text)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    private func distributionRow(_ text: String) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.72))
            Text(text.localized)
                .font(BBBFont.font(size: 10, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignToken.accentBlue.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.55), lineWidth: 1)
                )
        )
    }

    private func rarityStyle(for rarity: CompanionRarity) -> (tint: Color, text: Color) {
        switch rarity {
        case .common:
            return (DesignToken.accentBlue, DesignToken.textMuted)
        case .uncommon:
            return (DesignToken.success, DesignToken.successText)
        case .rare:
            return (DesignToken.primary, DesignToken.primary)
        case .precious:
            return (DesignToken.reward, DesignToken.rewardText)
        }
    }

    private func backdropStyle(for companion: BabyCompanion) -> (body: Color, accent: Color) {
        let visual = CompanionVisual.style(for: companion.id)
        return (visual.body, visual.accent)
    }

    private var isBuddyCardMotionEnabled: Bool {
        !reducedBuddyCardEffects && !reduceMotion
    }

    private var activeBuddyCardTilt: BuddyCardTilt {
        isBuddyCardMotionEnabled ? buddyCardMotion.tilt : .zero
    }

    private func refreshBuddyCardMotion() {
        buddyCardMotion.start(enabled: isBuddyCardMotionEnabled)
    }

    private func shouldUseHolographic(for rarity: CompanionRarity) -> Bool {
        switch rarity {
        case .rare, .precious:
            return true
        case .common, .uncommon:
            return false
        }
    }
}

struct CompanionAnimalFigure: View {
    let companion: BabyCompanion
    let isUnlocked: Bool
    let size: CGFloat
    @State private var shouldUseAssetPortrait = true

    private var visual: CompanionVisual {
        CompanionVisual.style(for: companion.id)
    }

    var body: some View {
        if let lockedMaskAssetName = companion.lockedMaskAssetName, !isUnlocked, shouldUseLockedMask {
            lockedMask(lockedMaskAssetName)
        } else {
            Group {
                if shouldUseAssetPortrait {
                    assetPortrait
                } else {
                    placeholderFigure
                }
            }
            .saturation(isUnlocked ? 1 : 0)
            .opacity(isUnlocked ? 1 : 0.58)
        }
    }

    private var assetPortrait: some View {
        Image(companion.portraitAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .onAppear {
                shouldUseAssetPortrait = UIImage(named: companion.portraitAssetName) != nil
            }
    }

    @State private var shouldUseLockedMask = true

    private func lockedMask(_ assetName: String) -> some View {
        Image(assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .onAppear {
                shouldUseLockedMask = UIImage(named: assetName) != nil
            }
    }

    private var placeholderFigure: some View {
        ZStack {
            Ellipse()
                .fill(DesignToken.shadowColor.opacity(isUnlocked ? 0.08 : 0.04))
                .frame(width: size * 0.62, height: size * 0.12)
                .offset(y: size * 0.35)

            tail
                .offset(x: size * 0.31, y: size * 0.10)

            bodyShape
                .offset(y: size * 0.10)

            bellyShape
                .offset(y: size * 0.15)

            ears
                .offset(y: -size * 0.16)

            headShape
                .offset(y: -size * 0.10)

            if isUnlocked {
                face
                    .offset(y: -size * 0.10)
                markings
                accessory
            }
        }
        .frame(width: size, height: size)
    }

    private var fillColor: Color {
        isUnlocked ? visual.body : DesignToken.surfaceSoft.opacity(0.62)
    }

    private var accentColor: Color {
        isUnlocked ? visual.accent : DesignToken.borderSubtle.opacity(0.52)
    }

    private var outlineColor: Color {
        isUnlocked ? CompanionRenderPalette.pigment("#5B534B").opacity(0.42) : DesignToken.textFaint.opacity(0.68)
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: isUnlocked ? 1.4 : 1.9, lineCap: .round, lineJoin: .round, dash: isUnlocked ? [] : [4.5, 4.5])
    }

    private var bodyShape: some View {
        styled(Ellipse(), fill: fillColor)
            .frame(width: size * visual.bodyWidth, height: size * visual.bodyHeight)
    }

    private var bellyShape: some View {
        Group {
            if isUnlocked {
                Ellipse()
                    .fill(visual.belly.opacity(0.72))
                    .frame(width: size * 0.30, height: size * 0.26)
            }
        }
    }

    private var headShape: some View {
        styled(Ellipse(), fill: fillColor)
            .frame(width: size * visual.headWidth, height: size * visual.headHeight)
    }

    @ViewBuilder
    private var ears: some View {
        switch visual.ears {
        case .long:
            HStack(spacing: size * 0.18) {
                styled(Capsule(), fill: fillColor)
                    .frame(width: size * 0.16, height: size * 0.44)
                    .rotationEffect(.degrees(-18))
                styled(Capsule(), fill: fillColor)
                    .frame(width: size * 0.16, height: size * 0.44)
                    .rotationEffect(.degrees(18))
            }
        case .pointy:
            HStack(spacing: size * 0.18) {
                styled(Triangle(), fill: fillColor)
                    .frame(width: size * 0.22, height: size * 0.24)
                    .rotationEffect(.degrees(-10))
                styled(Triangle(), fill: fillColor)
                    .frame(width: size * 0.22, height: size * 0.24)
                    .rotationEffect(.degrees(10))
            }
        case .round:
            HStack(spacing: size * 0.22) {
                styled(Circle(), fill: fillColor)
                    .frame(width: size * 0.24, height: size * 0.24)
                styled(Circle(), fill: fillColor)
                    .frame(width: size * 0.24, height: size * 0.24)
            }
        case .floppy:
            HStack(spacing: size * 0.28) {
                styled(Capsule(), fill: fillColor)
                    .frame(width: size * 0.16, height: size * 0.42)
                    .rotationEffect(.degrees(34))
                styled(Capsule(), fill: fillColor)
                    .frame(width: size * 0.16, height: size * 0.42)
                    .rotationEffect(.degrees(-34))
            }
        case .small:
            HStack(spacing: size * 0.18) {
                styled(Circle(), fill: fillColor)
                    .frame(width: size * 0.16, height: size * 0.16)
                styled(Circle(), fill: fillColor)
                    .frame(width: size * 0.16, height: size * 0.16)
            }
        }
    }

    @ViewBuilder
    private var tail: some View {
        switch visual.tail {
        case .curl:
            Circle()
                .trim(from: 0.18, to: 0.92)
                .stroke(isUnlocked ? visual.accent : outlineColor, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.22)
                .rotationEffect(.degrees(-12))
        case .fluffy:
            styled(Circle(), fill: accentColor)
                .frame(width: size * 0.28, height: size * 0.28)
        case .long:
            styled(Capsule(), fill: accentColor)
                .frame(width: size * 0.16, height: size * 0.46)
                .rotationEffect(.degrees(-38))
        case .short:
            styled(Circle(), fill: accentColor)
                .frame(width: size * 0.14, height: size * 0.14)
        case .none:
            EmptyView()
        }
    }

    private var face: some View {
        ZStack {
            HStack(spacing: size * 0.13) {
                Circle()
                    .fill(CompanionRenderPalette.pigment("#3C3834"))
                    .frame(width: size * 0.052, height: size * 0.052)
                Circle()
                    .fill(CompanionRenderPalette.pigment("#3C3834"))
                    .frame(width: size * 0.052, height: size * 0.052)
            }

            Group {
                if visual.mouth == .beak {
                    Triangle()
                        .fill(CompanionRenderPalette.pigment("#F6B34A"))
                        .frame(width: size * 0.13, height: size * 0.10)
                        .offset(y: size * 0.06)
                        .rotationEffect(.degrees(180))
                } else if visual.mouth == .snout {
                    Capsule()
                        .fill(CompanionRenderPalette.pigment("#F3A3A5"))
                        .frame(width: size * 0.20, height: size * 0.12)
                        .offset(y: size * 0.06)
                } else {
                    Circle()
                        .fill(CompanionRenderPalette.pigment("#4D4641"))
                        .frame(width: size * 0.07, height: size * 0.05)
                        .offset(y: size * 0.045)
                }
            }

            HStack(spacing: size * 0.22) {
                Circle()
                    .fill(CompanionRenderPalette.pigment("#EF8FA8").opacity(0.52))
                    .frame(width: size * 0.08, height: size * 0.06)
                Circle()
                    .fill(CompanionRenderPalette.pigment("#EF8FA8").opacity(0.52))
                    .frame(width: size * 0.08, height: size * 0.06)
            }
            .offset(y: size * 0.095)
        }
    }

    @ViewBuilder
    private var markings: some View {
        switch visual.marking {
        case .spots:
            ZStack {
                Circle().fill(visual.accent.opacity(0.80)).frame(width: size * 0.08).offset(x: -size * 0.14, y: -size * 0.18)
                Circle().fill(visual.accent.opacity(0.70)).frame(width: size * 0.06).offset(x: size * 0.13, y: -size * 0.02)
                Circle().fill(visual.accent.opacity(0.72)).frame(width: size * 0.07).offset(x: -size * 0.18, y: size * 0.14)
            }
        case .stripes:
            VStack(spacing: size * 0.035) {
                Capsule().fill(visual.accent.opacity(0.76)).frame(width: size * 0.26, height: size * 0.035)
                Capsule().fill(visual.accent.opacity(0.66)).frame(width: size * 0.22, height: size * 0.035)
                Capsule().fill(visual.accent.opacity(0.56)).frame(width: size * 0.18, height: size * 0.035)
            }
            .rotationEffect(.degrees(-18))
            .offset(x: size * 0.16, y: size * 0.10)
        case .mask:
            Capsule()
                .fill(visual.accent.opacity(0.82))
                .frame(width: size * 0.34, height: size * 0.14)
                .offset(y: -size * 0.10)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch visual.accessory {
        case .leaf:
            Capsule()
                .fill(CompanionRenderPalette.pigment("#77B86F"))
                .frame(width: size * 0.20, height: size * 0.07)
                .rotationEffect(.degrees(-28))
                .offset(x: size * 0.19, y: -size * 0.22)
        case .sailboat:
            Triangle()
                .fill(CompanionRenderPalette.pigment("#8BBDEB"))
                .frame(width: size * 0.10, height: size * 0.13)
                .offset(x: size * 0.12, y: size * 0.02)
        case .spark:
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.18, weight: .black))
                .foregroundStyle(CompanionRenderPalette.pigment("#FFB151"))
                .offset(x: size * 0.22, y: -size * 0.24)
        case .none:
            EmptyView()
        }
    }

    private func styled<S: Shape>(_ shape: S, fill: Color) -> some View {
        shape
            .fill(fill)
            .overlay(
                shape.stroke(outlineColor, style: strokeStyle)
            )
    }
}

private struct CompanionVisual {
    let body: Color
    let accent: Color
    let belly: Color
    let ears: EarStyle
    let tail: TailStyle
    let marking: Marking
    let mouth: Mouth
    let accessory: Accessory
    let bodyWidth: CGFloat
    let bodyHeight: CGFloat
    let headWidth: CGFloat
    let headHeight: CGFloat

    static func style(for id: String) -> CompanionVisual {
        switch id {
        case "piggy":
            return .init(body: CompanionRenderPalette.pigment("#F3A8B9"), accent: CompanionRenderPalette.pigment("#DD7B8E"), belly: CompanionRenderPalette.pigment("#FFD7DF"), ears: .small, tail: .curl, marking: .none, mouth: .snout, accessory: .none, bodyWidth: 0.56, bodyHeight: 0.52, headWidth: 0.46, headHeight: 0.38)
        case "fenny":
            return .init(body: CompanionRenderPalette.pigment("#F0A35E"), accent: CompanionRenderPalette.pigment("#F8D5A9"), belly: CompanionRenderPalette.pigment("#FFE3C6"), ears: .pointy, tail: .fluffy, marking: .mask, mouth: .nose, accessory: .none, bodyWidth: 0.52, bodyHeight: 0.50, headWidth: 0.46, headHeight: 0.38)
        case "ferry":
            return .init(body: CompanionRenderPalette.pigment("#D9C8B4"), accent: CompanionRenderPalette.pigment("#8E7564"), belly: CompanionRenderPalette.pigment("#F2E8DA"), ears: .round, tail: .long, marking: .stripes, mouth: .nose, accessory: .none, bodyWidth: 0.58, bodyHeight: 0.46, headWidth: 0.44, headHeight: 0.34)
        case "cal":
            return .init(body: CompanionRenderPalette.pigment("#FFF1A8"), accent: CompanionRenderPalette.pigment("#F4C85F"), belly: CompanionRenderPalette.pigment("#FFF8D7"), ears: .small, tail: .short, marking: .none, mouth: .beak, accessory: .none, bodyWidth: 0.54, bodyHeight: 0.50, headWidth: 0.44, headHeight: 0.38)
        case "bunny_lulu":
            return .init(body: CompanionRenderPalette.pigment("#F6DEC9"), accent: CompanionRenderPalette.pigment("#DFA6BE"), belly: CompanionRenderPalette.pigment("#FFF2E8"), ears: .long, tail: .fluffy, marking: .none, mouth: .nose, accessory: .none, bodyWidth: 0.48, bodyHeight: 0.50, headWidth: 0.42, headHeight: 0.36)
        case "fawn_mimi":
            return .init(body: CompanionRenderPalette.pigment("#D8A06F"), accent: CompanionRenderPalette.pigment("#FFF1D2"), belly: CompanionRenderPalette.pigment("#F8D8B4"), ears: .pointy, tail: .short, marking: .spots, mouth: .nose, accessory: .none, bodyWidth: 0.48, bodyHeight: 0.55, headWidth: 0.40, headHeight: 0.36)
        case "samoyed_momo":
            return .init(body: CompanionRenderPalette.pigment("#F6F2EA"), accent: CompanionRenderPalette.pigment("#D9D1C5"), belly: CompanionRenderPalette.pigment("#FFFFFF"), ears: .pointy, tail: .curl, marking: .none, mouth: .nose, accessory: .none, bodyWidth: 0.58, bodyHeight: 0.52, headWidth: 0.48, headHeight: 0.40)
        case "otter_tangtang":
            return .init(body: CompanionRenderPalette.pigment("#9D735D"), accent: CompanionRenderPalette.pigment("#6F4C3C"), belly: CompanionRenderPalette.pigment("#D8B496"), ears: .round, tail: .long, marking: .none, mouth: .nose, accessory: .none, bodyWidth: 0.48, bodyHeight: 0.54, headWidth: 0.42, headHeight: 0.36)
        case "redpanda_youyou":
            return .init(body: CompanionRenderPalette.pigment("#C86E43"), accent: CompanionRenderPalette.pigment("#5E3C32"), belly: CompanionRenderPalette.pigment("#F3D0B1"), ears: .pointy, tail: .fluffy, marking: .mask, mouth: .nose, accessory: .none, bodyWidth: 0.52, bodyHeight: 0.52, headWidth: 0.46, headHeight: 0.38)
        case "koala_anan":
            return .init(body: CompanionRenderPalette.pigment("#C8D0D4"), accent: CompanionRenderPalette.pigment("#8B969C"), belly: CompanionRenderPalette.pigment("#EEF1F2"), ears: .round, tail: .none, marking: .none, mouth: .nose, accessory: .leaf, bodyWidth: 0.52, bodyHeight: 0.54, headWidth: 0.50, headHeight: 0.40)
        case "sloth_nono":
            return .init(body: CompanionRenderPalette.pigment("#D8CBB8"), accent: CompanionRenderPalette.pigment("#8F806E"), belly: CompanionRenderPalette.pigment("#EFE4D4"), ears: .round, tail: .none, marking: .mask, mouth: .nose, accessory: .leaf, bodyWidth: 0.52, bodyHeight: 0.54, headWidth: 0.46, headHeight: 0.38)
        case "chipmunk_huohuo":
            return .init(body: CompanionRenderPalette.pigment("#D99A59"), accent: CompanionRenderPalette.pigment("#7B4A31"), belly: CompanionRenderPalette.pigment("#F6D1A6"), ears: .pointy, tail: .fluffy, marking: .stripes, mouth: .nose, accessory: .spark, bodyWidth: 0.48, bodyHeight: 0.52, headWidth: 0.42, headHeight: 0.36)
        default:
            return .init(body: DesignToken.primarySoft, accent: DesignToken.primary, belly: DesignToken.surfaceRaised, ears: .round, tail: .short, marking: .none, mouth: .nose, accessory: .none, bodyWidth: 0.52, bodyHeight: 0.52, headWidth: 0.44, headHeight: 0.38)
        }
    }

    enum EarStyle {
        case long
        case pointy
        case round
        case floppy
        case small
    }

    enum TailStyle {
        case curl
        case fluffy
        case long
        case short
        case none
    }

    enum Marking {
        case spots
        case stripes
        case mask
        case none
    }

    enum Mouth {
        case nose
        case snout
        case beak
    }

    enum Accessory {
        case leaf
        case sailboat
        case spark
        case none
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct DividerWave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 1, rect.height > 1 else {
            return path
        }

        let amplitude = rect.height * 0.22
        let segments = 36
        let segmentWidth = rect.width / CGFloat(segments)

        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for index in 0..<segments {
            let startX = rect.minX + CGFloat(index) * segmentWidth
            let endX = rect.minX + CGFloat(index + 1) * segmentWidth
            let controlX = (startX + endX) / 2
            let controlY = rect.midY + (index.isMultiple(of: 2) ? -amplitude : amplitude)
            path.addQuadCurve(
                to: CGPoint(x: endX, y: rect.midY),
                control: CGPoint(x: controlX, y: controlY)
            )
        }
        return path
    }
}
