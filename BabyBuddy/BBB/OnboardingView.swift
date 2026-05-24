import SwiftUI

struct OnboardingView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore

    let onComplete: () -> Void
    private let prefillFromProfile: Bool

    @State private var step = 0
    @State private var babyName = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
    @State private var gender: BabyGender = .boy
    @State private var answers: [TemperamentDimension: Double] = Dictionary(
        uniqueKeysWithValues: TemperamentQuestion.all.map { ($0.dimension, 3) }
    )
    @State private var result: TemperamentAnimal?
    @State private var selectedCompanionID: String?
    @State private var didHydrateFromProfile = false

    private let buddyColumns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10), count: 3)

    init(prefillFromProfile: Bool = false, onComplete: @escaping () -> Void) {
        self.prefillFromProfile = prefillFromProfile
        self.onComplete = onComplete
    }

    private var canContinueProfile: Bool {
        !babyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                onboardingBackground

                Group {
                    switch step {
                    case 0:
                        profilePage
                    case 1:
                        quizPage
                    default:
                        resultPage
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.86), value: step)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 {
                        Button {
                            step -= 1
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .tint(DesignToken.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(step + 1)/3")
                        .font(BBBFont.font(size: 13, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear(perform: hydrateFromProfileIfNeeded)
        }
    }

    private var onboardingBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "#F8F7FB"),
                Color(hex: "#F2F7FB"),
                Color(hex: "#F8F1F5")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var profilePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    title: "认识宝宝",
                    subtitle: "先记录基础信息，再为宝宝找到最像的气质小伙伴。"
                )

                VStack(spacing: 14) {
                    TextField("宝宝名字", text: $babyName)
                        .textInputAutocapitalization(.never)
                        .font(BBBFont.font(size: 17, weight: .semibold))
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))

                    Picker("性别", selection: $gender) {
                        ForEach(BabyGender.allCases) { gender in
                            Text("\(gender.emoji) \(genderTitle(gender))").tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("出生日期", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .font(BBBFont.font(size: 17, weight: .semibold))
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                }

                Spacer(minLength: 18)

                Button {
                    saveProfile()
                    step = 1
                } label: {
                    Text("开始气质小测试")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .font(BBBFont.font(size: 17, weight: .bold))
                .disabled(!canContinueProfile)
                .opacity(canContinueProfile ? 1 : 0.45)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var quizPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(
                    title: "9 个小问题",
                    subtitle: "按宝宝大多数时候的样子选择就好，没有标准答案。"
                )

                VStack(spacing: 12) {
                    ForEach(TemperamentQuestion.all) { question in
                        questionRow(question)
                    }
                }

                Button {
                    selectedCompanionID = nil
                    result = TemperamentEngine.match(scores: answers)
                    step = 2
                } label: {
                    Text("查看宝宝的小伙伴")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .font(BBBFont.font(size: 17, weight: .bold))
                .padding(.top, 8)
            }
            .padding(22)
        }
    }

    private var resultPage: some View {
        let matchedAnimal = result ?? TemperamentEngine.match(scores: answers)
        let selectedCompanion = selectedCompanionID.flatMap { id in
            BabyCompanion.all.first(where: { $0.id == id })
        } ?? BabyCompanion.companion(for: matchedAnimal.id)
        let selectedAnimal = TemperamentEngine.animal(for: selectedCompanion.id)
        let displayAnimal = selectedAnimal ?? matchedAnimal
        let savedType = selectedAnimal?.type ?? matchedAnimal.type

        return ScrollView {
            VStack(spacing: 20) {
                header(
                    title: "\(displayName) 的气质小伙伴",
                    subtitle: "这是一份当前倾向，不是固定标签。宝宝的节奏会随着成长继续变化。"
                )

                resultCard(
                    companion: selectedCompanion,
                    animal: selectedAnimal,
                    accent: displayAnimal.accent
                )

                HStack(spacing: 10) {
                    resultActionButton(title: "更改测试结果", icon: "slider.horizontal.3") {
                        selectedCompanionID = nil
                        step = 1
                    }

                    resultActionButton(title: "恢复推荐", icon: "arrow.counterclockwise") {
                        selectedCompanionID = nil
                    }
                    .opacity(selectedCompanion.id == matchedAnimal.id ? 0.45 : 1)
                    .disabled(selectedCompanion.id == matchedAnimal.id)
                }

                buddySelectionSection(
                    selectedCompanion: selectedCompanion,
                    matchedAnimal: matchedAnimal
                )

                Button {
                    saveProfile()
                    temperamentStore.update(
                        BabyTemperamentResult(
                            animalID: selectedCompanion.id,
                            type: savedType,
                            scores: answers,
                            completedAt: Date()
                        )
                    )
                    companionStore.selectedID = selectedCompanion.id
                    onComplete()
                } label: {
                    Text("进入 BabyBuddy")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .font(BBBFont.font(size: 17, weight: .bold))
            }
            .padding(22)
        }
    }

    private func resultCard(companion: BabyCompanion, animal: TemperamentAnimal?, accent: Color) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 210, height: 210)
                Circle()
                    .fill(.white.opacity(0.88))
                    .frame(width: 174, height: 174)
                RoundedRectangle(cornerRadius: 44, style: .continuous)
                    .stroke(accent.opacity(0.20), lineWidth: 1.5)
                    .frame(width: 174, height: 174)
                Image(companion.portraitAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 190)
                    .shadow(color: accent.opacity(0.18), radius: 18, y: 10)
            }
            .frame(height: 214)

            VStack(spacing: 6) {
                Text("\(companion.chineseName) · \(companion.species)")
                    .font(BBBFont.font(size: 20, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .multilineTextAlignment(.center)
                Text(resultSlogan(for: animal, companion: companion))
                    .font(BBBFont.font(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
            }

            Text(companion.intro)
                .font(BBBFont.font(size: 15, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(accent.opacity(0.14))
                )

            Text(resultSummary(for: animal, companion: companion))
                .font(BBBFont.font(size: 17, weight: .semibold))
                .foregroundStyle(DesignToken.textPrimary)
                .multilineTextAlignment(.center)

            Text(resultPersonality(for: animal, companion: companion))
                .font(BBBFont.font(size: 15, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white.opacity(0.9)))
    }

    private func buddySelectionSection(selectedCompanion: BabyCompanion, matchedAnimal: TemperamentAnimal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自选 Buddy")
                        .font(BBBFont.font(size: 19, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("测评推荐：\(matchedAnimal.name)")
                        .font(BBBFont.font(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                if selectedCompanion.id != matchedAnimal.id {
                    Text("已自选")
                        .font(BBBFont.font(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Capsule().fill(DesignToken.primaryGradient))
                }
            }

            LazyVGrid(columns: buddyColumns, spacing: 10) {
                ForEach(BabyCompanion.all) { companion in
                    companionOptionButton(
                        companion,
                        selectedID: selectedCompanion.id,
                        matchedID: matchedAnimal.id,
                        accent: TemperamentEngine.animal(for: companion.id)?.accent ?? DesignToken.primary
                    )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.88)))
    }

    private func companionOptionButton(_ companion: BabyCompanion, selectedID: String, matchedID: String, accent: Color) -> some View {
        let isSelected = companion.id == selectedID
        let isMatched = companion.id == matchedID

        return Button {
            selectedCompanionID = companion.id
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(accent.opacity(isSelected ? 0.18 : 0.10))
                        .frame(width: 66, height: 66)
                    Image(companion.portraitAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 68, height: 68)
                        .shadow(color: accent.opacity(isSelected ? 0.18 : 0.08), radius: 10, y: 5)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DesignToken.primary)
                            .background(Circle().fill(.white))
                            .offset(x: 3, y: -1)
                    }
                }
                .frame(height: 70)

                Text(companion.chineseName)
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(isMatched ? "测评推荐" : companion.species)
                    .font(BBBFont.font(size: 10, weight: .bold))
                    .foregroundStyle(isMatched ? DesignToken.primary : DesignToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.13) : .white.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.72) : DesignToken.line.opacity(0.34), lineWidth: isSelected ? 1.8 : 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func resultActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                Text(title)
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(DesignToken.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                Capsule()
                    .fill(.white.opacity(0.9))
                    .overlay(Capsule().stroke(DesignToken.line.opacity(0.42), lineWidth: 1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BBBFont.font(size: 28, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            Text(subtitle)
                .font(BBBFont.font(size: 15, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func questionRow(_ question: TemperamentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.text)
                .font(BBBFont.font(size: 17, weight: .semibold))
                .foregroundStyle(DesignToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text("不像")
                Slider(
                    value: binding(for: question.dimension),
                    in: 1...5,
                    step: 1
                )
                .tint(DesignToken.primary)
                Text("很像")
            }
            .font(BBBFont.font(size: 12, weight: .bold))
            .foregroundStyle(DesignToken.textSecondary)

            HStack {
                ForEach(1...5, id: \.self) { value in
                    Text("\(value)")
                        .font(BBBFont.font(size: 11, weight: .bold))
                        .foregroundStyle(currentScore(for: question.dimension) == Double(value) ? DesignToken.primary : DesignToken.textSecondary.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.92)))
    }

    private func binding(for dimension: TemperamentDimension) -> Binding<Double> {
        Binding {
            answers[dimension] ?? 3
        } set: { newValue in
            answers[dimension] = newValue
        }
    }

    private func currentScore(for dimension: TemperamentDimension) -> Double {
        answers[dimension] ?? 3
    }

    private var displayName: String {
        let trimmed = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "宝宝" : trimmed
    }

    private func genderTitle(_ gender: BabyGender) -> String {
        switch gender {
        case .boy: return "男宝"
        case .girl: return "女宝"
        }
    }

    private func hydrateFromProfileIfNeeded() {
        guard prefillFromProfile, !didHydrateFromProfile else { return }

        let profile = profileStore.currentProfile
        babyName = profile.name
        birthDate = min(profile.birthDate, Date())
        gender = profile.gender

        if let savedResult = temperamentStore.result {
            var hydratedAnswers = answers
            savedResult.scores.forEach { dimension, score in
                hydratedAnswers[dimension] = score
            }
            answers = hydratedAnswers
            result = TemperamentEngine.animal(for: savedResult.animalID) ?? TemperamentEngine.match(scores: hydratedAnswers)
            selectedCompanionID = BabyCompanion.all.contains(where: { $0.id == savedResult.animalID })
                ? savedResult.animalID
                : companionStore.selectedID
        } else {
            selectedCompanionID = companionStore.selectedID
        }

        didHydrateFromProfile = true
    }

    private func saveProfile() {
        let trimmedName = babyName.trimmingCharacters(in: .whitespacesAndNewlines)

        if prefillFromProfile {
            let currentProfile = profileStore.currentProfile
            profileStore.create(
                name: trimmedName,
                gender: gender,
                birthDate: birthDate,
                avatarEmoji: currentProfile.avatarEmoji,
                avatarImageData: currentProfile.avatarImageData
            )
        } else {
            profileStore.create(
                name: trimmedName,
                gender: gender,
                birthDate: birthDate
            )
        }
    }

    private func resultSlogan(for animal: TemperamentAnimal?, companion: BabyCompanion) -> String {
        animal?.slogan ?? "你为宝宝选中的小伙伴"
    }

    private func resultSummary(for animal: TemperamentAnimal?, companion: BabyCompanion) -> String {
        animal?.summary ?? "\(companion.chineseName)会成为宝宝当前的 Buddy，也会出现在陪伴页。"
    }

    private func resultPersonality(for animal: TemperamentAnimal?, companion: BabyCompanion) -> String {
        animal?.personality ?? "测试答案会继续保留；这一次，你可以按直觉选择最想陪在宝宝身边的伙伴。"
    }
}

private struct TemperamentQuestion: Identifiable {
    let id: String
    let dimension: TemperamentDimension
    let text: String

    static let all: [TemperamentQuestion] = [
        .init(id: "q01", dimension: .activityLevel, text: "宝宝醒着的时候，通常动作很多、很爱动。"),
        .init(id: "q02", dimension: .regularity, text: "宝宝吃奶、睡觉、便便的时间，大多比较有规律。"),
        .init(id: "q03", dimension: .approach, text: "遇到新玩具、新人或新环境时，宝宝通常愿意靠近或尝试。"),
        .init(id: "q04", dimension: .adaptability, text: "生活节奏有变化时，宝宝通常能比较快适应。"),
        .init(id: "q05", dimension: .intensity, text: "宝宝开心、难过或不舒服时，反应通常很强烈。"),
        .init(id: "q06", dimension: .mood, text: "宝宝平时整体看起来比较轻松、爱笑、好相处。"),
        .init(id: "q07", dimension: .attentionPersistence, text: "宝宝对喜欢的事物，通常能持续关注一会儿。"),
        .init(id: "q08", dimension: .distractibility, text: "周围一点动静，就很容易把宝宝的注意力带走。"),
        .init(id: "q09", dimension: .sensorySensitivity, text: "光线、声音、触感这些小变化，宝宝也很容易察觉并有反应。")
    ]
}

private struct TemperamentAnimal: Identifiable {
    let id: String
    let name: String
    let species: String
    let type: TemperamentType
    let emoji: String
    let accent: Color
    let slogan: String
    let characterLine: String
    let personality: String
    let summary: String
    let profile: [TemperamentDimension: Double]
}

private enum TemperamentEngine {
    static func match(scores: [TemperamentDimension: Double]) -> TemperamentAnimal {
        let type = matchType(scores: scores)
        let candidates = animals.filter { $0.type == type }
        return candidates.min { distance(scores, $0.profile) < distance(scores, $1.profile) }
            ?? animals[0]
    }

    static func animal(for id: String) -> TemperamentAnimal? {
        animals.first { $0.id == id }
    }

    private static func matchType(scores: [TemperamentDimension: Double]) -> TemperamentType {
        let ranked = typeProfiles
            .map { (type: $0.key, distance: distance(scores, $0.value)) }
            .sorted { $0.distance < $1.distance }

        guard let first = ranked.first else { return .intermediate }
        if ranked.count > 1, ranked[1].distance - first.distance < 0.6 {
            return .intermediate
        }
        return first.type
    }

    private static func distance(_ scores: [TemperamentDimension: Double], _ profile: [TemperamentDimension: Double]) -> Double {
        TemperamentDimension.allCases.reduce(0) { total, dimension in
            let diff = (scores[dimension] ?? 3) - (profile[dimension] ?? 3)
            return total + diff * diff
        }
    }

    private static let typeProfiles: [TemperamentType: [TemperamentDimension: Double]] = [
        .easy: [.activityLevel: 3, .regularity: 5, .approach: 4, .adaptability: 5, .intensity: 2, .mood: 5, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 2],
        .intermediate: [.activityLevel: 3, .regularity: 3, .approach: 3, .adaptability: 3, .intensity: 3, .mood: 3, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 3],
        .slowToWarmUp: [.activityLevel: 2, .regularity: 3, .approach: 2, .adaptability: 2, .intensity: 2, .mood: 3, .attentionPersistence: 4, .distractibility: 2, .sensorySensitivity: 4],
        .highSensitivity: [.activityLevel: 4, .regularity: 1, .approach: 2, .adaptability: 1, .intensity: 5, .mood: 2, .attentionPersistence: 3, .distractibility: 4, .sensorySensitivity: 5]
    ]

    private static let animals: [TemperamentAnimal] = [
        .init(id: "bunny_lulu", name: "洛噗", species: "荷兰垂耳兔幼兔", type: .easy, emoji: "🐰", accent: Color(hex: "#E7A7C4"), slogan: "软软甜甜的小太阳", characterLine: "稳定亲近、反应柔和，是容易被轻轻引导的小甜心。", personality: "洛噗通常节奏稳定，笑容很多，遇到新变化也愿意慢慢试试看。", summary: "大多数时候都比较轻松好带，也很愿意和熟悉的人互动。", profile: [.activityLevel: 3, .regularity: 5, .approach: 4, .adaptability: 5, .intensity: 2, .mood: 5, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 2]),
        .init(id: "fawn_mimi", name: "西咔", species: "梅花鹿幼崽", type: .easy, emoji: "🦌", accent: Color(hex: "#D8A96A"), slogan: "温柔安静的小晨光", characterLine: "安静细腻、喜欢熟悉节奏，需要被温柔守护。", personality: "西咔温和细腻，作息比较有节奏，和熟悉的人在一起时特别放松。", summary: "她带着柔和的小步调，让陪伴变得轻轻的、稳稳的。", profile: [.activityLevel: 2, .regularity: 5, .approach: 3, .adaptability: 5, .intensity: 2, .mood: 5, .attentionPersistence: 3, .distractibility: 2, .sensorySensitivity: 3]),
        .init(id: "cal", name: "柯噜", species: "柯尔鸭幼鸭", type: .easy, emoji: "🦆", accent: Color(hex: "#F0C85A"), slogan: "慢半拍的小圆团", characterLine: "圆滚滚、步伐慢半拍，擅长把普通日常变得可爱。", personality: "柯噜总是带着慢半拍的小节奏，回应温和，也很容易被日常里的小事情逗开心。", summary: "像一只把好心情慢慢带来的小鸭子，让照护节奏变得轻松又可爱。", profile: [.activityLevel: 3, .regularity: 5, .approach: 5, .adaptability: 5, .intensity: 3, .mood: 5, .attentionPersistence: 2, .distractibility: 4, .sensorySensitivity: 2]),
        .init(id: "samoyed_momo", name: "摩耶", species: "萨摩耶幼犬", type: .easy, emoji: "🐶", accent: Color(hex: "#A8C7FF"), slogan: "笑眯眯的小棉花糖", characterLine: "亲和稳定、适应力强，像随时给人安心的陪伴。", personality: "摩耶亲和、情绪稳定，进入新场景时往往也比较从容。", summary: "稳定、亲近，也很容易让照护者找到节奏。", profile: [.activityLevel: 3, .regularity: 5, .approach: 5, .adaptability: 5, .intensity: 3, .mood: 5, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 2]),
        .init(id: "otter_tangtang", name: "欧缇", species: "亚洲小爪水獭幼崽", type: .intermediate, emoji: "🦦", accent: Color(hex: "#8BC7B1"), slogan: "今天想撒娇，明天想探险", characterLine: "状态丰富、节奏多变，需要弹性和耐心配合。", personality: "欧缇有时轻松好带，有时又特别有自己的节奏，像在不同状态间轻轻切换。", summary: "不是一种固定模板，而是很有层次的小宝宝。", profile: [.activityLevel: 3, .regularity: 3, .approach: 4, .adaptability: 3, .intensity: 3, .mood: 4, .attentionPersistence: 3, .distractibility: 4, .sensorySensitivity: 3]),
        .init(id: "fenny", name: "芬灵", species: "耳廓狐幼崽", type: .intermediate, emoji: "🦊", accent: Color(hex: "#E9A05E"), slogan: "机灵又讲感觉的小观察家", characterLine: "敏锐聪明、先观察再靠近，对环境里的细节特别有感觉。", personality: "芬灵对外界很敏锐，有时热情靠近，有时又想先看看再说。", summary: "他有自己的感受节奏，需要被理解，而不是被催着快一点。", profile: [.activityLevel: 4, .regularity: 3, .approach: 3, .adaptability: 3, .intensity: 3, .mood: 3, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 5]),
        .init(id: "redpanda_youyou", name: "瑞迪", species: "小熊猫幼崽", type: .intermediate, emoji: "🐾", accent: Color(hex: "#C88968"), slogan: "有主见的小团子", characterLine: "柔软但有主见，喜欢按自己的方式慢慢进入状态。", personality: "瑞迪既有柔软的一面，也有坚持自己步调的一面，时而乖巧，时而很有态度。", summary: "不是不好带，只是更需要按自己的方式慢慢配合。", profile: [.activityLevel: 3, .regularity: 3, .approach: 3, .adaptability: 2, .intensity: 3, .mood: 3, .attentionPersistence: 5, .distractibility: 2, .sensorySensitivity: 3]),
        .init(id: "koala_anan", name: "阿考", species: "昆士兰考拉幼崽", type: .slowToWarmUp, emoji: "🐨", accent: Color(hex: "#9BB1B8"), slogan: "慢热但很认真的小月亮", characterLine: "慢热谨慎、观察力强，安全感足够后会认真靠近。", personality: "阿考不急着靠近世界，更喜欢先观察，等准备好了才慢慢伸出小手。", summary: "不是慢，而是会先把安全感装满。", profile: [.activityLevel: 2, .regularity: 3, .approach: 1, .adaptability: 2, .intensity: 2, .mood: 3, .attentionPersistence: 5, .distractibility: 2, .sensorySensitivity: 5]),
        .init(id: "sloth_nono", name: "霍菲", species: "霍氏树懒幼崽", type: .slowToWarmUp, emoji: "🌿", accent: Color(hex: "#8FB98A"), slogan: "慢一点，也一样很可爱", characterLine: "慢节奏、低刺激偏好，需要更从容的过渡时间。", personality: "霍菲喜欢按照自己的小节奏前进，换环境时会先停一停、看一看。", summary: "给他一点缓冲时间，他会用自己的方式慢慢打开。", profile: [.activityLevel: 1, .regularity: 3, .approach: 1, .adaptability: 2, .intensity: 2, .mood: 3, .attentionPersistence: 3, .distractibility: 2, .sensorySensitivity: 3]),
        .init(id: "chipmunk_huohuo", name: "奇比", species: "西伯利亚花栗鼠幼崽", type: .highSensitivity, emoji: "✨", accent: Color(hex: "#FF7A70"), slogan: "反应快、感觉多的小火花", characterLine: "感受强烈、反应很快，需要更多安抚和提前预告。", personality: "奇比感受丰富、反应迅速，喜欢立刻表达自己的不舒服，也常常需要更多安抚和理解。", summary: "不是故意难带，只是比别人更敏锐、更强烈地感受这个世界。", profile: [.activityLevel: 4, .regularity: 1, .approach: 2, .adaptability: 1, .intensity: 5, .mood: 2, .attentionPersistence: 3, .distractibility: 4, .sensorySensitivity: 5])
    ]
}
