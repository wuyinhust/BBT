import SwiftUI

struct OnboardingView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore

    let onComplete: () -> Void

    @State private var step = 0
    @State private var babyName = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
    @State private var gender: BabyGender = .boy
    @State private var answers: [TemperamentDimension: Double] = Dictionary(
        uniqueKeysWithValues: TemperamentQuestion.all.map { ($0.dimension, 3) }
    )
    @State private var result: TemperamentAnimal?

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
                                .font(.headline.weight(.semibold))
                        }
                        .tint(DesignToken.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(step + 1)/3")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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
                        .font(.title3.weight(.semibold))
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
                        .font(.headline)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                }

                Spacer(minLength: 18)

                Button {
                    profileStore.create(
                        name: babyName.trimmingCharacters(in: .whitespacesAndNewlines),
                        gender: gender,
                        birthDate: birthDate
                    )
                    step = 1
                } label: {
                    Text("开始气质小测试")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .font(.headline.weight(.bold))
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
                    result = TemperamentEngine.match(scores: answers)
                    step = 2
                } label: {
                    Text("查看宝宝的小伙伴")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .font(.headline.weight(.bold))
                .padding(.top, 8)
            }
            .padding(22)
        }
    }

    private var resultPage: some View {
        let animal = result ?? TemperamentEngine.match(scores: answers)

        return ScrollView {
            VStack(spacing: 20) {
                header(
                    title: "\(displayName) 的气质小伙伴",
                    subtitle: "这是一份当前倾向，不是固定标签。宝宝的节奏会随着成长继续变化。"
                )

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(animal.accent.opacity(0.16))
                            .frame(width: 190, height: 190)
                        RoundedRectangle(cornerRadius: 44, style: .continuous)
                            .fill(.white.opacity(0.88))
                            .frame(width: 164, height: 164)
                            .overlay(
                                Text(animal.emoji)
                                    .font(.system(size: 92))
                            )
                    }

                    VStack(spacing: 6) {
                        Text("\(animal.name) · \(animal.species)")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(animal.slogan)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(animal.accent)
                    }

                    Text(animal.summary)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(animal.personality)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(22)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white.opacity(0.9)))

                Button {
                    profileStore.create(
                        name: babyName.trimmingCharacters(in: .whitespacesAndNewlines),
                        gender: gender,
                        birthDate: birthDate
                    )
                    temperamentStore.update(
                        BabyTemperamentResult(
                            animalID: animal.id,
                            type: animal.type,
                            scores: answers,
                            completedAt: Date()
                        )
                    )
                    onComplete()
                } label: {
                    Text("进入 BabyBuddy")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .font(.headline.weight(.bold))
            }
            .padding(22)
        }
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(DesignToken.textPrimary)
            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func questionRow(_ question: TemperamentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.text)
                .font(.headline.weight(.semibold))
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
            .font(.caption.weight(.bold))
            .foregroundStyle(DesignToken.textSecondary)

            HStack {
                ForEach(1...5, id: \.self) { value in
                    Text("\(value)")
                        .font(.caption2.weight(.bold))
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
        .init(id: "bunny_lulu", name: "露露", species: "垂耳兔宝宝", type: .easy, emoji: "🐰", accent: Color(hex: "#E7A7C4"), slogan: "软软甜甜的小太阳", personality: "露露通常节奏稳定，笑容很多，遇到新变化也愿意慢慢试试看。", summary: "大多数时候都比较轻松好带，也很愿意和熟悉的人互动。", profile: [.activityLevel: 3, .regularity: 5, .approach: 4, .adaptability: 5, .intensity: 2, .mood: 5, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 2]),
        .init(id: "fawn_mimi", name: "米米", species: "幼鹿", type: .easy, emoji: "🦌", accent: Color(hex: "#D8A96A"), slogan: "温柔安静的小晨光", personality: "米米温和细腻，作息比较有节奏，和熟悉的人在一起时特别放松。", summary: "她带着柔和的小步调，让陪伴变得轻轻的、稳稳的。", profile: [.activityLevel: 2, .regularity: 5, .approach: 3, .adaptability: 5, .intensity: 2, .mood: 5, .attentionPersistence: 3, .distractibility: 2, .sensorySensitivity: 3]),
        .init(id: "duck_pepe", name: "沛沛", species: "小黄鸭", type: .easy, emoji: "🦆", accent: Color(hex: "#F0C85A"), slogan: "咕噜咕噜的快乐宝宝", personality: "沛沛对世界常常很好奇，愿意互动，开心来得快，恢复也快。", summary: "像一只自带好心情的小鸭子，轻轻一逗就有回应。", profile: [.activityLevel: 3, .regularity: 5, .approach: 5, .adaptability: 5, .intensity: 3, .mood: 5, .attentionPersistence: 2, .distractibility: 4, .sensorySensitivity: 2]),
        .init(id: "samoyed_momo", name: "默默", species: "萨摩耶幼犬", type: .easy, emoji: "🐶", accent: Color(hex: "#A8C7FF"), slogan: "笑眯眯的小棉花糖", personality: "默默亲和、情绪稳定，进入新场景时往往也比较从容。", summary: "稳定、亲近，也很容易让照护者找到节奏。", profile: [.activityLevel: 3, .regularity: 5, .approach: 5, .adaptability: 5, .intensity: 3, .mood: 5, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 2]),
        .init(id: "otter_tangtang", name: "糖糖", species: "小海獭", type: .intermediate, emoji: "🦦", accent: Color(hex: "#8BC7B1"), slogan: "今天想撒娇，明天想探险", personality: "糖糖有时轻松好带，有时又特别有自己的节奏，像在不同状态间轻轻切换。", summary: "不是一种固定模板，而是很有层次的小宝宝。", profile: [.activityLevel: 3, .regularity: 3, .approach: 4, .adaptability: 3, .intensity: 3, .mood: 4, .attentionPersistence: 3, .distractibility: 4, .sensorySensitivity: 3]),
        .init(id: "fox_pudding", name: "布丁", species: "耳廓狐宝宝", type: .intermediate, emoji: "🦊", accent: Color(hex: "#E9A05E"), slogan: "机灵又讲感觉的小观察家", personality: "布丁对外界很敏锐，有时热情靠近，有时又想先看看再说。", summary: "他有自己的感受节奏，需要被理解，而不是被催着快一点。", profile: [.activityLevel: 4, .regularity: 3, .approach: 3, .adaptability: 3, .intensity: 3, .mood: 3, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 5]),
        .init(id: "redpanda_youyou", name: "柚柚", species: "小熊猫", type: .intermediate, emoji: "🐾", accent: Color(hex: "#C88968"), slogan: "有主见的小团子", personality: "柚柚既有柔软的一面，也有坚持自己步调的一面，时而乖巧，时而很有态度。", summary: "不是不好带，只是更需要按自己的方式慢慢配合。", profile: [.activityLevel: 3, .regularity: 3, .approach: 3, .adaptability: 2, .intensity: 3, .mood: 3, .attentionPersistence: 5, .distractibility: 2, .sensorySensitivity: 3]),
        .init(id: "koala_anan", name: "安安", species: "小考拉", type: .slowToWarmUp, emoji: "🐨", accent: Color(hex: "#9BB1B8"), slogan: "慢热但很认真的小月亮", personality: "安安不急着靠近世界，更喜欢先观察，等准备好了才慢慢伸出小手。", summary: "不是慢，而是会先把安全感装满。", profile: [.activityLevel: 2, .regularity: 3, .approach: 1, .adaptability: 2, .intensity: 2, .mood: 3, .attentionPersistence: 5, .distractibility: 2, .sensorySensitivity: 5]),
        .init(id: "sloth_nono", name: "诺诺", species: "树懒宝宝", type: .slowToWarmUp, emoji: "🌿", accent: Color(hex: "#8FB98A"), slogan: "慢一点，也一样很可爱", personality: "诺诺喜欢按照自己的小节奏前进，换环境时会先停一停、看一看。", summary: "给他一点缓冲时间，他会用自己的方式慢慢打开。", profile: [.activityLevel: 1, .regularity: 3, .approach: 1, .adaptability: 2, .intensity: 2, .mood: 3, .attentionPersistence: 3, .distractibility: 2, .sensorySensitivity: 3]),
        .init(id: "chipmunk_huohuo", name: "火火", species: "花栗鼠宝宝", type: .highSensitivity, emoji: "✨", accent: Color(hex: "#FF7A70"), slogan: "反应快、感觉多的小火花", personality: "火火感受丰富、反应迅速，喜欢立刻表达自己的不舒服，也常常需要更多安抚和理解。", summary: "不是故意难带，只是比别人更敏锐、更强烈地感受这个世界。", profile: [.activityLevel: 4, .regularity: 1, .approach: 2, .adaptability: 1, .intensity: 5, .mood: 2, .attentionPersistence: 3, .distractibility: 4, .sensorySensitivity: 5])
    ]
}
