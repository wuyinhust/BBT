import SwiftUI
import UIKit

struct CompanionPickerView: View {
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @Binding var isPresented: Bool

    @State private var selectedCompanion: BabyCompanion?

    private let cardAspectRatio: CGFloat = 0.72
    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10), count: 3)

    var body: some View {
        ZStack {
            pickerBackground

            VStack(spacing: 16) {
                topBar

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                        ForEach(BabyCompanion.all) { companion in
                            companionGridButton(companion)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 42)
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
    }

    private var pickerBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#F8F7FB"),
                    Color(hex: "#F5F1FA"),
                    Color(hex: "#EEF6FB")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white.opacity(0.70),
                    Color.white.opacity(0.0)
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
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.92))
                            .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 12, y: 5)
                    )
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text("BBBuddy")
                    .font(BBBFont.font(size: 21, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignToken.primary, Color(hex: "#343348")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                .accessibilityLabel("BBBuddy")

                Text("选择今天陪伴宝宝的伙伴")
                    .font(BBBFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
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
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(Capsule().fill(DesignToken.primaryGradient))
                            .offset(x: 1, y: 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 82)

                VStack(spacing: 3) {
                    Text(isUnlocked ? companion.chineseName : "未解锁")
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(isUnlocked ? DesignToken.textPrimary : DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(isUnlocked ? companion.species : friendshipText(for: companion))
                        .font(BBBFont.font(size: 8, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
            .padding(.horizontal, 7)
            .padding(.top, 13)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .aspectRatio(cardAspectRatio, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.92), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.04), radius: 10, y: 5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isUnlocked ? "\(companion.chineseName), \(companion.species)" : "未获取伙伴")
    }

    private func companionDetailOverlay(_ companion: BabyCompanion) -> some View {
        let isUnlocked = isCompanionUnlocked(companion)

        return ZStack(alignment: .bottom) {
            Color.black.opacity(0.26)
                .ignoresSafeArea()
                .onTapGesture {
                    selectedCompanion = nil
                }

            VStack(spacing: 0) {
                HStack {
                    Button {
                        selectedCompanion = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(.white.opacity(0.94)))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                Spacer(minLength: 12)

                VStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(isUnlocked ? companion.chineseName : "未解锁伙伴")
                            .font(BBBFont.font(size: 23, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text(isUnlocked ? companion.englishName : "Keep caring")
                            .font(BBBFont.font(size: 13, weight: .heavy))
                            .foregroundStyle(DesignToken.textSecondary)
                    }

                    CompanionAnimalFigure(
                        companion: companion,
                        isUnlocked: isUnlocked,
                        size: 208
                    )
                    .frame(maxWidth: .infinity, minHeight: 218, maxHeight: 218, alignment: .center)
                    .padding(.top, 2)

                    if isUnlocked {
                        unlockedDetail(companion)
                    } else {
                        lockedDetail(companion)
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: min(UIScreen.main.bounds.height * 0.68, 660))
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFFDFE"),
                                Color(hex: "#F8F7FB")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.16), radius: 24, y: -8)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    private func unlockedDetail(_ companion: BabyCompanion) -> some View {
        VStack(spacing: 12) {
            Text(companion.species)
                .font(BBBFont.font(size: 13, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.center)

            Text(companion.intro)
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.textBody)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white.opacity(0.94))
                        .overlay(alignment: .top) {
                            Triangle()
                                .fill(.white)
                                .frame(width: 28, height: 16)
                                .offset(y: -13)
                        }
                        .shadow(color: Color(hex: "#4D4B70").opacity(0.055), radius: 12, y: 6)
                )

            DividerWave()
                .stroke(DesignToken.primary.opacity(0.24), lineWidth: 1.5)
                .frame(height: 12)

            detailStats(companion: companion, isUnlocked: true)

            Button {
                companionStore.selectedID = companion.id
                selectedCompanion = nil
                isPresented = false
            } label: {
                Text(companionStore.selectedID == companion.id ? "当前伙伴" : "设为当前伙伴")
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(DesignToken.primaryGradient))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
    }

    private func lockedDetail(_ companion: BabyCompanion) -> some View {
        VStack(spacing: 12) {
            Text("友情值 \(Int((recruitmentStore.friendshipPercent(for: companion.id) * 100).rounded()))%")
                .font(BBBFont.font(size: 17, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.90)))

            DividerWave()
                .stroke(DesignToken.primary.opacity(0.24), lineWidth: 1.5)
                .frame(height: 12)

            detailStats(companion: companion, isUnlocked: false)

            Text("在陪伴页的 yesterday's 中用 BB Bucks 准备小点心，友情值满后解锁。")
                .font(BBBFont.font(size: 13, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func detailStats(companion: BabyCompanion, isUnlocked: Bool) -> some View {
        VStack(spacing: 10) {
            statRow(title: "收集难度", count: collectDifficulty(for: companion), color: DesignToken.primary)

            if isUnlocked {
                statRow(title: "好感度", count: affectionLevel(for: companion), color: DesignToken.primarySoft)
            }
        }
    }

    private func statRow(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(BBBFont.font(size: 14, weight: .bold))
                .foregroundStyle(DesignToken.textBody)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index < count ? color : DesignToken.grayNeutral)
                        .frame(width: 9, height: 9)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 39)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.70))
        )
    }

    private func isCompanionUnlocked(_ companion: BabyCompanion) -> Bool {
        recruitmentStore.isUnlocked(
            companion,
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID
        )
    }

    private func friendshipText(for companion: BabyCompanion) -> String {
        let percent = Int((recruitmentStore.friendshipPercent(for: companion.id) * 100).rounded())
        return percent > 0 ? "友情值 \(percent)%" : "等待来访"
    }

    private func collectDifficulty(for companion: BabyCompanion) -> Int {
        switch companion.rarity {
        case .common: return 1
        case .uncommon: return 2
        case .rare, .precious: return 3
        }
    }

    private func affectionLevel(for companion: BabyCompanion) -> Int {
        switch companion.id {
        case "piggy", "bunny_lulu", "samoyed_momo":
            return 3
        case "cal", "fawn_mimi", "otter_tangtang":
            return 2
        default:
            return 1
        }
    }
}

private struct CompanionAnimalFigure: View {
    let companion: BabyCompanion
    let isUnlocked: Bool
    let size: CGFloat
    @State private var shouldUseAssetPortrait = true

    private var visual: CompanionVisual {
        CompanionVisual.style(for: companion.id)
    }

    var body: some View {
        Group {
            if let lockedMaskAssetName = companion.lockedMaskAssetName, !isUnlocked, shouldUseLockedMask {
                lockedMask(lockedMaskAssetName)
            } else if shouldUseAssetPortrait {
                assetPortrait
            } else {
                placeholderFigure
            }
        }
        .saturation(isUnlocked ? 1 : 0)
        .opacity(isUnlocked ? 1 : 0.58)
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
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color(hex: "#A9A3AF"))
            .frame(width: size, height: size)
            .onAppear {
                shouldUseLockedMask = UIImage(named: assetName) != nil
            }
    }

    private var placeholderFigure: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(isUnlocked ? 0.08 : 0.04))
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
        isUnlocked ? visual.body : Color(hex: "#EEE7DC").opacity(0.62)
    }

    private var accentColor: Color {
        isUnlocked ? visual.accent : Color(hex: "#8A8176").opacity(0.24)
    }

    private var outlineColor: Color {
        isUnlocked ? Color(hex: "#5B534B").opacity(0.42) : Color(hex: "#8A8176").opacity(0.68)
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
                    .fill(Color(hex: "#3C3834"))
                    .frame(width: size * 0.052, height: size * 0.052)
                Circle()
                    .fill(Color(hex: "#3C3834"))
                    .frame(width: size * 0.052, height: size * 0.052)
            }

            Group {
                if visual.mouth == .beak {
                    Triangle()
                        .fill(Color(hex: "#F6B34A"))
                        .frame(width: size * 0.13, height: size * 0.10)
                        .offset(y: size * 0.06)
                        .rotationEffect(.degrees(180))
                } else if visual.mouth == .snout {
                    Capsule()
                        .fill(Color(hex: "#F3A3A5"))
                        .frame(width: size * 0.20, height: size * 0.12)
                        .offset(y: size * 0.06)
                } else {
                    Circle()
                        .fill(Color(hex: "#4D4641"))
                        .frame(width: size * 0.07, height: size * 0.05)
                        .offset(y: size * 0.045)
                }
            }

            HStack(spacing: size * 0.22) {
                Circle()
                    .fill(Color(hex: "#EF8FA8").opacity(0.52))
                    .frame(width: size * 0.08, height: size * 0.06)
                Circle()
                    .fill(Color(hex: "#EF8FA8").opacity(0.52))
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
                .fill(Color(hex: "#77B86F"))
                .frame(width: size * 0.20, height: size * 0.07)
                .rotationEffect(.degrees(-28))
                .offset(x: size * 0.19, y: -size * 0.22)
        case .sailboat:
            Triangle()
                .fill(Color(hex: "#8BBDEB"))
                .frame(width: size * 0.10, height: size * 0.13)
                .offset(x: size * 0.12, y: size * 0.02)
        case .spark:
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.18, weight: .black))
                .foregroundStyle(Color(hex: "#FFB151"))
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
            return .init(body: Color(hex: "#F3A8B9"), accent: Color(hex: "#DD7B8E"), belly: Color(hex: "#FFD7DF"), ears: .small, tail: .curl, marking: .none, mouth: .snout, accessory: .none, bodyWidth: 0.56, bodyHeight: 0.52, headWidth: 0.46, headHeight: 0.38)
        case "fenny":
            return .init(body: Color(hex: "#F0A35E"), accent: Color(hex: "#F8D5A9"), belly: Color(hex: "#FFE3C6"), ears: .pointy, tail: .fluffy, marking: .mask, mouth: .nose, accessory: .none, bodyWidth: 0.52, bodyHeight: 0.50, headWidth: 0.46, headHeight: 0.38)
        case "ferry":
            return .init(body: Color(hex: "#D9C8B4"), accent: Color(hex: "#8E7564"), belly: Color(hex: "#F2E8DA"), ears: .round, tail: .long, marking: .stripes, mouth: .nose, accessory: .none, bodyWidth: 0.58, bodyHeight: 0.46, headWidth: 0.44, headHeight: 0.34)
        case "cal":
            return .init(body: Color(hex: "#FFF1A8"), accent: Color(hex: "#F4C85F"), belly: Color(hex: "#FFF8D7"), ears: .small, tail: .short, marking: .none, mouth: .beak, accessory: .none, bodyWidth: 0.54, bodyHeight: 0.50, headWidth: 0.44, headHeight: 0.38)
        case "bunny_lulu":
            return .init(body: Color(hex: "#F6DEC9"), accent: Color(hex: "#DFA6BE"), belly: Color(hex: "#FFF2E8"), ears: .long, tail: .fluffy, marking: .none, mouth: .nose, accessory: .none, bodyWidth: 0.48, bodyHeight: 0.50, headWidth: 0.42, headHeight: 0.36)
        case "fawn_mimi":
            return .init(body: Color(hex: "#D8A06F"), accent: Color(hex: "#FFF1D2"), belly: Color(hex: "#F8D8B4"), ears: .pointy, tail: .short, marking: .spots, mouth: .nose, accessory: .none, bodyWidth: 0.48, bodyHeight: 0.55, headWidth: 0.40, headHeight: 0.36)
        case "samoyed_momo":
            return .init(body: Color(hex: "#F6F2EA"), accent: Color(hex: "#D9D1C5"), belly: Color(hex: "#FFFFFF"), ears: .pointy, tail: .curl, marking: .none, mouth: .nose, accessory: .none, bodyWidth: 0.58, bodyHeight: 0.52, headWidth: 0.48, headHeight: 0.40)
        case "otter_tangtang":
            return .init(body: Color(hex: "#9D735D"), accent: Color(hex: "#6F4C3C"), belly: Color(hex: "#D8B496"), ears: .round, tail: .long, marking: .none, mouth: .nose, accessory: .none, bodyWidth: 0.48, bodyHeight: 0.54, headWidth: 0.42, headHeight: 0.36)
        case "redpanda_youyou":
            return .init(body: Color(hex: "#C86E43"), accent: Color(hex: "#5E3C32"), belly: Color(hex: "#F3D0B1"), ears: .pointy, tail: .fluffy, marking: .mask, mouth: .nose, accessory: .none, bodyWidth: 0.52, bodyHeight: 0.52, headWidth: 0.46, headHeight: 0.38)
        case "koala_anan":
            return .init(body: Color(hex: "#C8D0D4"), accent: Color(hex: "#8B969C"), belly: Color(hex: "#EEF1F2"), ears: .round, tail: .none, marking: .none, mouth: .nose, accessory: .leaf, bodyWidth: 0.52, bodyHeight: 0.54, headWidth: 0.50, headHeight: 0.40)
        case "sloth_nono":
            return .init(body: Color(hex: "#D8CBB8"), accent: Color(hex: "#8F806E"), belly: Color(hex: "#EFE4D4"), ears: .round, tail: .none, marking: .mask, mouth: .nose, accessory: .leaf, bodyWidth: 0.52, bodyHeight: 0.54, headWidth: 0.46, headHeight: 0.38)
        case "chipmunk_huohuo":
            return .init(body: Color(hex: "#D99A59"), accent: Color(hex: "#7B4A31"), belly: Color(hex: "#F6D1A6"), ears: .pointy, tail: .fluffy, marking: .stripes, mouth: .nose, accessory: .spark, bodyWidth: 0.48, bodyHeight: 0.52, headWidth: 0.42, headHeight: 0.36)
        default:
            return .init(body: DesignToken.primarySoft, accent: DesignToken.primary, belly: .white, ears: .round, tail: .short, marking: .none, mouth: .nose, accessory: .none, bodyWidth: 0.52, bodyHeight: 0.52, headWidth: 0.44, headHeight: 0.38)
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
