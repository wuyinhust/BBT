import AVFoundation
import Combine
import Speech
import SwiftUI
import UIKit

struct VoiceRecordRoute: Identifiable {
    let id = UUID()
}

enum VoiceMilkKind: Equatable {
    case formula
    case expressed
    case nursing
    case solids
}

enum VoiceDiaperKind: Equatable {
    case peeLow
    case peeMedium
    case peeHigh
    case poopHard
    case poopFormed
    case poopPaste
    case poopWatery
    case poopMucus
}

enum VoiceRecordDraft: Equatable {
    case feeding(kind: VoiceMilkKind, amount: Int, recordedAt: Date)
    case solid(food: SolidFood, amount: Double, unit: SolidUnit, recordedAt: Date)
    case diaper(kind: VoiceDiaperKind, recordedAt: Date)
    case activity(title: String, durationMinutes: Int?, recordedAt: Date)
    case sleep(startAt: Date, endAt: Date)
    case growth(kind: GrowthMetricKind, value: Double, recordedAt: Date)
    case subjective(babyState: BabySubjectiveState?, parentState: ParentSubjectiveState?, recordedAt: Date)

    var title: String {
        switch self {
        case .feeding(let kind, _, _):
            switch kind {
            case .formula: return VoiceRecordCopy.formula
            case .expressed: return VoiceRecordCopy.expressed
            case .nursing: return VoiceRecordCopy.nursing
            case .solids: return VoiceRecordCopy.solids
            }
        case .solid(let food, _, _, _):
            return food.localizedDisplayName
        case .diaper(let kind, _):
            return kind.isPee ? VoiceRecordCopy.wetDiaper : VoiceRecordCopy.poopDiaper
        case .activity(let title, _, _):
            return title
        case .sleep:
            return VoiceRecordCopy.sleep
        case .growth(let kind, _, _):
            return kind.title
        case .subjective:
            return VoiceRecordCopy.subjectiveState
        }
    }

    var summary: String {
        switch self {
        case .feeding(let kind, let amount, _):
            switch kind {
            case .formula, .expressed:
                return "\(amount) ml"
            case .nursing:
                return AppQuantityFormat.minutes(amount)
            case .solids:
                return "\(amount) g"
            }
        case .solid(_, let amount, let unit, _):
            return "\(VoiceRecordParser.numberText(amount)) \(unit.displayName)"
        case .diaper(let kind, _):
            return kind.displayDetail
        case .activity(_, let durationMinutes, _):
            return durationMinutes.map(AppQuantityFormat.minutes) ?? VoiceRecordCopy.activityCompleted
        case .sleep(let startAt, let endAt):
            let minutes = SleepRecordFormatter.durationMinutes(start: startAt, end: endAt)
            return "\(AppDateTimeFormat.time(startAt))–\(AppDateTimeFormat.time(endAt)) · \(AppQuantityFormat.hoursAndMinutes(minutes))"
        case .growth(let kind, let value, _):
            return "\(VoiceRecordParser.numberText(value)) \(kind.unit)"
        case .subjective(let babyState, let parentState, _):
            return [babyState?.title, parentState?.title].compactMap { $0 }.joined(separator: " · ")
        }
    }

    var recordedAt: Date {
        switch self {
        case .feeding(_, _, let date), .solid(_, _, _, let date), .diaper(_, let date), .activity(_, _, let date), .growth(_, _, let date),
             .subjective(_, _, let date):
            return date
        case .sleep(let startAt, _):
            return startAt
        }
    }

    var icon: String {
        switch self {
        case .feeding(let kind, _, _):
            switch kind {
            case .formula, .expressed: return "baby.bottle.fill"
            case .nursing: return "heart.fill"
            case .solids: return "fork.knife"
            }
        case .solid:
            return "fork.knife"
        case .diaper(let kind, _):
            return kind.isPee ? "drop.fill" : "circle.grid.2x2.fill"
        case .activity:
            return "sparkles"
        case .sleep:
            return "moon.zzz.fill"
        case .growth(let kind, _, _):
            return kind.icon
        case .subjective:
            return "heart.text.square.fill"
        }
    }

    var color: Color {
        switch self {
        case .feeding, .solid:
            return DesignToken.easyEat
        case .diaper, .activity:
            return DesignToken.easyActivity
        case .sleep:
            return DesignToken.easySleep
        case .growth(let kind, _, _):
            return kind.accent
        case .subjective:
            return DesignToken.easyYearning
        }
    }
}

private extension VoiceDiaperKind {
    var isPee: Bool {
        switch self {
        case .peeLow, .peeMedium, .peeHigh: return true
        case .poopHard, .poopFormed, .poopPaste, .poopWatery, .poopMucus: return false
        }
    }

    var detail: String {
        switch self {
        case .peeLow: return "尿了一点💧"
        case .peeMedium: return "尿了不少💧💧"
        case .peeHigh: return "尿了很多💧💧💧"
        case .poopHard: return "硬结便"
        case .poopFormed: return "成型便"
        case .poopPaste: return "糊状便"
        case .poopWatery: return "稀水便"
        case .poopMucus: return "黏液便"
        }
    }

    var displayDetail: String {
        VoiceRecordCopy.diaperDetail(self)
    }
}

enum VoiceRecordParseError: Error, Equatable {
    case empty
    case unsupported
    case missingAmount
    case invalidValue

    var message: String {
        switch self {
        case .empty: return VoiceRecordCopy.noSpeech
        case .unsupported: return VoiceRecordCopy.unsupportedSpeech
        case .missingAmount: return VoiceRecordCopy.missingAmount
        case .invalidValue: return VoiceRecordCopy.invalidValue
        }
    }
}

enum VoiceSpeechLocale {
    static func identifier(
        language: AppLanguage,
        regionIdentifier: String?,
        supportedIdentifiers: Set<String>
    ) -> String {
        let region = regionIdentifier?.uppercased()
        let candidates: [String]
        switch language {
        case .simplifiedChinese:
            // Apple Speech currently has no zh-SG acoustic model. Singapore
            // Mandarin therefore uses zh-CN plus Singapore-specific phrases.
            candidates = ["zh-CN"]
        case .traditionalChinese:
            candidates = [region == "HK" || region == "MO" ? "zh-HK" : "zh-TW", "zh-TW", "zh-HK"]
        case .english:
            let regionalEnglish = region.map { "en-\($0)" }
            candidates = [regionalEnglish, region == "GB" ? "en-GB" : "en-US", "en-US", "en-GB"]
                .compactMap { $0 }
        }
        return candidates.first(where: supportedIdentifiers.contains) ?? candidates[0]
    }

    static func preferred(
        language: AppLanguage = AppLocalization.language,
        regionalLocale: Locale = .autoupdatingCurrent,
        supportedLocales: Set<Locale> = SFSpeechRecognizer.supportedLocales()
    ) -> Locale {
        let supportedIdentifiers = Set(supportedLocales.map(\.identifier))
        return Locale(identifier: identifier(
            language: language,
            regionIdentifier: regionalLocale.region?.identifier,
            supportedIdentifiers: supportedIdentifiers
        ))
    }
}

enum VoiceRecordParser {
    static func parse(_ transcript: String, referenceDate: Date = Date()) -> Result<VoiceRecordDraft, VoiceRecordParseError> {
        let text = normalized(transcript)
        guard !text.isEmpty else { return .failure(.empty) }

        let bottleAmount = feedingAmount(in: text)
        let hasBottleUnit = containsAny(text, [
            "毫升", "ml", "milliliter", "milliliters", "millilitre", "millilitres",
            "ounce", "ounces", "fl oz", "oz"
        ])
        let hasDurationUnit = containsAny(text, ["分钟", "分鐘", "分", "小时", "小時", "minute", "minutes", "hour", "hours"])

        if containsAny(text, ["体重", "體重", "公斤", "千克", "kg", "weight", "weighs", "weighed", "pound", "pounds", "lbs", "lb"]) {
            let value = number(beforeAny: ["公斤", "千克", "kg"], in: text)
                ?? number(beforeAny: ["pounds", "pound", "lbs", "lb"], in: text).map { $0 * 0.453_592_37 }
            guard let value else {
                return .failure(.missingAmount)
            }
            guard GrowthMetricKind.weight.validRange.contains(value) else { return .failure(.invalidValue) }
            return .success(.growth(kind: .weight, value: value, recordedAt: recordDate(in: text, referenceDate: referenceDate)))
        }

        if containsAny(text, ["身高", "身长", "身長", "厘米", "cm", "height", "length", "inch", "inches"]) {
            let value = number(beforeAny: ["厘米", "cm"], in: text)
                ?? number(beforeAny: ["inches", "inch"], in: text).map { $0 * 2.54 }
            guard let value else {
                return .failure(.missingAmount)
            }
            guard GrowthMetricKind.height.validRange.contains(value) else { return .failure(.invalidValue) }
            return .success(.growth(kind: .height, value: value, recordedAt: recordDate(in: text, referenceDate: referenceDate)))
        }

        let hasSleepRecordIntent = containsAny(text, [
            "睡眠", "睡了", "睡到", "睡着", "睡著", "入睡", "刚醒", "剛醒", "醒了", "醒来", "醒來",
            "小睡", "夜睡", "瞓咗", "瞓到", "醒咗", "sleep", "slept", "nap", "napped", "fell asleep", "woke", "woke up"
        ])
        if hasSleepRecordIntent {
            guard let window = sleepWindow(in: text, referenceDate: referenceDate),
                  window.end > window.start,
                  window.end <= referenceDate,
                  window.end.timeIntervalSince(window.start) <= TimeInterval(SleepRecordFormatter.maximumDurationMinutes * 60) else {
                return .failure(.invalidValue)
            }
            return .success(.sleep(startAt: window.start, endAt: window.end))
        }

        let poopTerms = [
            "便便", "大便", "稀便", "水便", "黏液便", "粘液便", "硬结便", "硬結便", "成型便", "糊状便", "糊狀便",
            "拉了", "拉屎", "拉粑粑", "拉臭臭", "粑粑", "排便", "便咗", "屙咗", "屙便便",
            "poop", "pooped", "pooed", "did a poo", "had a poo", "bowel movement", "dirty diaper", "dirty nappy", "soiled diaper", "soiled nappy"
        ]
        let peeTerms = [
            // Mainland China and Singapore Mandarin.
            "尿布", "尿片", "尿湿", "尿濕", "尿了", "尿咗", "尿尿", "小便", "嘘嘘", "噓噓",
            // Taiwan Mandarin and Hong Kong usage.
            "尿布濕", "尿布湿", "尿片濕", "尿片湿", "濕片", "湿片", "瀨尿", "濑尿", "屙尿", "有尿",
            // US, UK and Singapore English.
            "diaper", "nappy", "wet diaper", "wet nappy", "peed", "pee pee", "had a pee", "did a pee", "urinated",
            "had a wee", "did a wee", "wee wee", "weeed", "wet himself", "wet herself"
        ]
        let hasPoopIntent = containsAny(text, poopTerms) || containsEnglishWord("poo", in: text)
        let hasPeeIntent = containsAny(text, peeTerms)
            || containsEnglishWord("pee", in: text)
            || containsEnglishWord("wee", in: text)
        if hasPeeIntent || hasPoopIntent {
            let kind: VoiceDiaperKind
            if hasPoopIntent {
                if containsAny(text, ["硬", "干"] ) {
                    kind = .poopHard
                } else if containsAny(text, ["成型", "条状", "条"] ) {
                    kind = .poopFormed
                } else if containsAny(text, ["稀", "水样", "水樣", "水便"] ) {
                    kind = .poopWatery
                } else if containsAny(text, ["黏液", "粘液"] ) {
                    kind = .poopMucus
                } else {
                    kind = .poopPaste
                }
            } else if containsAny(text, ["not very wet", "wasn't very wet", "was not very wet", "not much pee", "not much wee"]) {
                kind = .peeLow
            } else if containsAny(text, [
                "很多", "好多", "超多", "大量", "特别湿", "特別濕", "湿透", "濕透", "全湿", "全濕", "满了", "滿了",
                "爆尿", "尿爆", "成片尿", "好濕", "好湿", "勁濕", "劲湿",
                "very wet", "really wet", "extremely wet", "soaking wet", "soaked", "saturated", "sopping wet",
                "heavy wet diaper", "heavy diaper", "heavy wet nappy", "heavy nappy", "full diaper", "full nappy", "a lot of pee", "big wee"
            ]) {
                kind = .peeHigh
            } else if containsAny(text, [
                "不少", "挺多", "蠻多", "蛮多", "好些", "好幾多", "几多", "幾多",
                "quite wet", "pretty wet", "fairly wet", "a fair amount", "a good amount", "decent amount"
            ]) {
                kind = .peeMedium
            } else if containsAny(text, [
                "一点点", "一點點", "一点", "一點", "少量", "少少", "有点湿", "有點濕", "微湿", "微濕", "不太多", "唔多",
                "a little pee", "a little wee", "little pee", "little wee", "tiny bit", "small amount", "small wee",
                "peed a little", "did a little wee", "little bit of pee", "little bit of wee",
                "slightly wet", "lightly wet", "a bit wet", "a little wet", "damp diaper", "damp nappy"
            ]) {
                kind = .peeLow
            } else {
                kind = .peeMedium
            }
            return .success(.diaper(kind: kind, recordedAt: recordDate(in: text, referenceDate: referenceDate)))
        }

        let solidTerms = [
            "辅食", "輔食", "副食品", "米粉", "米糊", "米精", "麥精", "麦精", "果泥", "菜泥", "肉泥", "粥", "面条", "麵條",
            "鸡蛋", "雞蛋", "蛋黄", "蛋黃", "水果", "蔬菜", "鱼肉", "魚肉", "酸奶", "面包", "麵包",
            "solid food", "solids", "weaning food", "baby cereal", "rice cereal", "puree", "porridge", "yogurt", "yoghurt"
        ]
        let hasFeedingIntent = containsAny(text, [
            "奶粉", "配方奶", "奶", "瓶喂", "瓶餵", "亲喂", "親餵", "母乳", "母奶", "人奶", "埋身餵", "奶樽", "食奶", "食咗奶", "飲奶", "飲咗奶",
            "喂奶", "餵奶",
            "吃了", "吃的", "吃过", "吃過", "喂了", "餵了", "喝奶", "喝了", "formula", "bottle",
            "breast milk", "breastmilk", "milk", "nursed", "nursing", "breastfed", "breast-fed", "breastfeeding",
            "solid food", "solids", "weaning food", "drank", "fed", "had a feed", "took a bottle"
        ] + solidTerms)
        if hasFeedingIntent {
            let recordedAt = recordDate(in: text, referenceDate: referenceDate)
            if containsAny(text, solidTerms) {
                guard let quantity = solidQuantity(in: text) else {
                    return .failure(.missingAmount)
                }
                guard quantity.amount > 0, quantity.amount <= 2_000 else { return .failure(.invalidValue) }
                return .success(.solid(
                    food: solidFood(in: text),
                    amount: quantity.amount,
                    unit: quantity.unit,
                    recordedAt: recordedAt
                ))
            }
            let hasNursingIntent = containsAny(text, [
                "亲喂", "親餵", "母乳喂", "母乳餵", "左边", "左邊", "右边", "右邊", "左侧", "左側",
                "右侧", "右側", "左乳", "右乳", "左右各", "兩邊", "两边", "埋身餵", "埋身喂", "吸了",
                "nursed", "nursing", "breastfed", "breast-fed", "breastfeeding", "latched", "left breast", "right breast", "both breasts", "both sides", "each side"
            ]) || (text.contains("母乳") && hasDurationUnit && !hasBottleUnit)
            if hasNursingIntent {
                let duration = nursingDurationMinutes(in: text) ?? 10
                guard (1...60).contains(duration) else { return .failure(.invalidValue) }
                return .success(.feeding(kind: .nursing, amount: duration, recordedAt: recordedAt))
            }
            guard let amount = bottleAmount else { return .failure(.missingAmount) }
            guard (10...240).contains(amount) else { return .failure(.invalidValue) }
            let kind: VoiceMilkKind = containsAny(text, [
                "母乳", "母乳瓶", "瓶喂母乳", "瓶餵母乳", "奶瓶母乳", "储奶", "儲奶", "冷藏奶",
                "冻奶", "凍奶", "母奶", "人奶", "吸出来的奶", "吸出來的奶", "expressed milk", "expressed breast milk",
                "expressed breastmilk", "pumped milk"
            ]) ? .expressed : .formula
            return .success(.feeding(kind: kind, amount: amount, recordedAt: recordedAt))
        }

        let babyState = subjectiveBabyState(in: text)
        let parentState = subjectiveParentState(in: text)
        if babyState != nil || parentState != nil {
            return .success(.subjective(
                babyState: babyState,
                parentState: parentState,
                recordedAt: recordDate(in: text, referenceDate: referenceDate)
            ))
        }

        let activities: [(title: String, aliases: [String])] = [
            ("趴卧", ["趴卧", "趴趴", "趴着玩", "趴著玩", "tummy time", "played on tummy"]),
            ("翻身训练", ["翻身训练", "翻身訓練", "练翻身", "練翻身", "rolling practice", "roll over practice"]),
            ("黑白卡", ["黑白卡", "black and white cards", "contrast cards"]),
            ("追物训练", ["追物训练", "追物訓練", "追视", "追視", "visual tracking", "tracking practice"]),
            ("抓握", ["抓握", "抓东西", "抓東西", "grasping practice", "grabbing toys"]),
            ("健身架", ["健身架", "play gym", "baby gym"]),
            ("悬挂玩具", ["悬挂玩具", "懸掛玩具", "吊挂玩具", "吊掛玩具", "hanging toys", "baby mobile"]),
            ("对视聊天", ["对视聊天", "對視聊天", "聊天", "说话互动", "說話互動", "face to face", "talked to baby"]),
            ("照镜子", ["照镜子", "照鏡子", "看镜子", "看鏡子", "mirror play", "looked in the mirror"]),
            ("绘本", ["绘本", "繪本", "读书", "讀書", "讲故事", "講故事", "看书", "看書", "story time", "read a book", "read to baby"]),
            ("布书", ["布书", "布書", "cloth book", "soft book"]),
            ("音乐律动", ["音乐律动", "音樂律動", "听音乐", "聽音樂", "music time", "listened to music"]),
            ("听儿歌", ["听儿歌", "聽兒歌", "儿歌", "兒歌", "nursery rhymes", "sang songs"]),
            ("户外活动", ["户外活动", "戶外活動", "出门", "出門", "散步", "遛弯", "遛彎", "晒太阳", "曬太陽", "went outside", "went outdoors", "went for a walk"]),
            ("室内活动", ["室内活动", "室內活動", "玩耍", "玩了一会", "玩了一會", "indoor play", "play time", "played indoors"]),
            ("抚触", ["抚触", "撫觸", "按摩", "baby massage", "gave a massage"]),
            ("排气操", ["排气操", "排氣操", "bicycle legs", "gas exercise"]),
            ("排嗝", ["排嗝", "拍嗝", "打嗝", "burped", "winded the baby"]),
            ("飞机抱", ["飞机抱", "飛機抱", "airplane hold", "tiger in the tree hold"]),
            ("洗澡", ["洗澡", "洗了澡", "bath", "bathed", "had a bath"]),
            ("剪指甲", ["剪指甲", "剪了指甲", "trimmed nails", "cut baby's nails"]),
            ("刷牙", ["刷牙", "刷了牙", "brushed teeth", "tooth brushing"]),
            ("日常护理", ["换衣服", "換衣服", "洗脸", "洗臉", "喂药", "餵藥", "吃药", "吃藥", "changed clothes", "washed face", "gave medicine"])
        ]
        let matchedActivities = activities
            .filter { containsAny(text, $0.aliases) }
            .map(\.title)
        if !matchedActivities.isEmpty {
            return .success(.activity(
                title: matchedActivities.joined(separator: " "),
                durationMinutes: durationMinutes(in: text),
                recordedAt: recordDate(in: text, referenceDate: referenceDate)
            ))
        }

        return .failure(.unsupported)
    }

    static func numberText(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func fallbackDraft(for transcript: String, referenceDate: Date = Date()) -> VoiceRecordDraft {
        let text = normalized(transcript)
        let recordedAt = recordDate(in: text, referenceDate: referenceDate)

        if containsAny(text, ["身高", "身长", "身長", "厘米", "cm", "height"]) {
            return .growth(kind: .height, value: number(beforeAny: ["厘米", "cm"], in: text) ?? 65, recordedAt: recordedAt)
        }
        if containsAny(text, ["体重", "體重", "公斤", "千克", "kg", "weight"]) {
            return .growth(kind: .weight, value: number(beforeAny: ["公斤", "千克", "kg"], in: text) ?? 7, recordedAt: recordedAt)
        }
        if containsAny(text, [
            "睡眠", "睡了", "睡到", "睡着", "睡著", "入睡", "刚醒", "剛醒", "醒了", "醒来", "醒來",
            "小睡", "夜睡", "瞓咗", "瞓到", "醒咗", "sleep", "slept", "nap", "napped", "woke"
        ]) {
            if let window = sleepWindow(in: text, referenceDate: referenceDate), window.end > window.start {
                return .sleep(startAt: window.start, endAt: window.end)
            }
            return .sleep(startAt: referenceDate.addingTimeInterval(-30 * 60), endAt: referenceDate)
        }
        let isFallbackPoop = containsAny(text, ["便", "拉", "粑粑", "大便", "poop", "屙便"])
            || containsEnglishWord("poo", in: text)
        let isFallbackPee = containsAny(text, ["尿", "瀨", "濑", "diaper", "nappy"])
            || containsEnglishWord("pee", in: text)
            || containsEnglishWord("wee", in: text)
        if isFallbackPoop || isFallbackPee {
            let isPoop = isFallbackPoop
            return .diaper(kind: isPoop ? .poopPaste : .peeMedium, recordedAt: recordedAt)
        }
        if containsAny(text, ["奶", "吃", "喝", "飲", "食奶", "喂", "餵", "母乳", "母奶", "人奶", "辅食", "輔食", "bottle", "milk", "fed", "nursing", "breastfed", "solids"]) {
            let kind: VoiceMilkKind
            let amount: Int
            if containsAny(text, ["亲喂", "親餵", "埋身餵", "左右", "兩邊", "两边", "左边", "右边", "nursing", "breastfed"]) {
                kind = .nursing
                amount = nursingDurationMinutes(in: text) ?? 15
            } else if containsAny(text, ["辅食", "輔食", "米", "粥", "泥", "蛋", "菜", "水果", "solid food", "solids", "weaning food", "cereal"]) {
                let quantity = solidQuantity(in: text) ?? (amount: 30, unit: SolidUnit.g)
                return .solid(
                    food: solidFood(in: text),
                    amount: quantity.amount,
                    unit: quantity.unit,
                    recordedAt: recordedAt
                )
            } else {
                kind = containsAny(text, ["母乳", "母奶", "人奶", "储奶", "儲奶", "冷藏奶", "冻奶", "凍奶", "expressed", "pumped milk"]) ? .expressed : .formula
                amount = feedingAmount(in: text) ?? 120
            }
            return .feeding(kind: kind, amount: amount, recordedAt: recordedAt)
        }
        let babyState = subjectiveBabyState(in: text)
        let parentState = subjectiveParentState(in: text)
        if babyState != nil || parentState != nil {
            return .subjective(babyState: babyState, parentState: parentState, recordedAt: recordedAt)
        }

        let title = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return .activity(
            title: title.isEmpty ? VoiceRecordCopy.genericActivity : title,
            durationMinutes: durationMinutes(in: text),
            recordedAt: recordedAt
        )
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            // Common Apple Speech homophones in the baby-care domain.
            .replacingOccurrences(of: "母亲未", with: "母乳亲喂")
            .replacingOccurrences(of: "母親未", with: "母乳親餵")
            .replacingOccurrences(of: "母乳亲未", with: "母乳亲喂")
            .replacingOccurrences(of: "母乳親未", with: "母乳親餵")
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "。", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains(where: text.contains)
    }

    private static func containsEnglishWord(_ word: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        guard let expression = try? NSRegularExpression(pattern: "\\b\(escaped)\\b") else { return false }
        return expression.firstMatch(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        ) != nil
    }

    private static func number(beforeAny units: [String], in text: String) -> Double? {
        for unit in units {
            let escaped = NSRegularExpression.escapedPattern(for: unit)
            let pattern = "(\(numberTokenPattern))\\s*\(escaped)"
            if let token = firstCapture(pattern: pattern, in: text), let value = parseNumber(token) {
                return value
            }
        }
        return nil
    }

    private static func integer(beforeAny units: [String], in text: String) -> Int? {
        number(beforeAny: units, in: text).map { Int($0.rounded()) }
    }

    private static func feedingAmount(in text: String) -> Int? {
        if let amount = integer(beforeAny: ["毫升", "ml", "milliliters", "milliliter", "millilitres", "millilitre"], in: text) {
            return amount
        }
        if let ounces = number(beforeAny: ["fluid ounces", "fluid ounce", "fl oz", "ounces", "ounce", "oz"], in: text) {
            return Int((ounces * 29.573_529_562_5).rounded())
        }
        let numberToken = "(\(numberTokenPattern))"
        let beforeMilk = "\(numberToken)\\s*(?:的)?\\s*(?:配方奶|奶粉|奶|formula|breast ?milk|milk)"
        if let token = firstCapture(pattern: beforeMilk, in: text), let value = parseNumber(token) {
            return Int(value.rounded())
        }
        let afterDrink = "(?:喝了|喝奶|喂了|餵了|飲咗|食咗|drank|fed|took|had)\\s*\(numberToken)"
        if let token = firstCapture(pattern: afterDrink, in: text), let value = parseNumber(token) {
            return Int(value.rounded())
        }
        return nil
    }

    private static func subjectiveBabyState(in text: String) -> BabySubjectiveState? {
        if containsAny(text, ["好奇", "探索", "好奇心"]) { return .curious }
        if containsAny(text, ["开心", "開心", "高兴", "高興", "满足", "滿足", "心情好", "happy", "cheerful", "content"]) { return .happy }
        if containsAny(text, ["平静", "平靜", "安稳", "安穩", "很乖", "很安静", "很安靜", "calm", "settled", "peaceful"]) { return .calm }
        if containsAny(text, ["烦躁", "煩躁", "闹腾", "鬧騰", "不耐烦", "不耐煩", "哼唧", "扭計", "fussy", "unsettled", "irritable"]) { return .fussy }
        if containsAny(text, ["哭闹", "哭鬧", "哭了", "大哭", "一直哭", "喊緊", "crying", "cried"]) { return .crying }
        if containsAny(text, ["困倦", "犯困", "想睡", "瞌睡", "打哈欠", "眼瞓", "sleepy", "drowsy", "yawning"]) { return .sleepy }
        return nil
    }

    private static func solidFood(in text: String) -> SolidFood {
        if containsAny(text, ["粥", "稀饭", "稀飯", "porridge"]) { return .porridge }
        if containsAny(text, ["蔬菜", "菜泥", "青菜", "vegetable"]) { return .vegetable }
        if containsAny(text, ["水果", "果泥", "苹果", "蘋果", "香蕉", "fruit"]) { return .fruit }
        if containsAny(text, ["肉泥", "肉类", "肉類", "猪肉", "豬肉", "牛肉", "鸡肉", "雞肉"]) { return .meat }
        if containsAny(text, ["鱼肉", "魚肉", "鱼泥", "魚泥"]) { return .fish }
        if containsAny(text, ["鸡蛋", "雞蛋", "蛋黄", "蛋黃", "蛋白"]) { return .egg }
        if containsAny(text, ["面条", "麵條", "面片"]) { return .noodle }
        if containsAny(text, ["面包", "麵包", "吐司"]) { return .bread }
        if containsAny(text, ["酸奶", "優格", "优格", "yogurt", "yoghurt"]) { return .yogurt }
        if containsAny(text, ["米糊", "米粉", "米精", "麥精", "麦精", "大米", "baby cereal", "rice cereal"]) { return .rice }
        return .other
    }

    private static func solidQuantity(in text: String) -> (amount: Double, unit: SolidUnit)? {
        if let ounces = number(beforeAny: ["ounces", "ounce", "oz"], in: text) {
            return (ounces * 28.349_523_125, .g)
        }
        let mappings: [(tokens: [String], unit: SolidUnit)] = [
            (["大勺", "汤匙", "湯匙", "tablespoons", "tablespoon", "tbsp"], .tbsp),
            (["小勺", "茶匙", "勺", "teaspoons", "teaspoon", "tsp"], .tsp),
            (["毫升", "ml", "milliliters", "milliliter", "millilitres", "millilitre"], .ml),
            (["克", "grams", "gram", "g"], .g),
            (["块", "塊", "片", "个", "個", "pieces", "piece", "slices", "slice"], .piece)
        ]
        for mapping in mappings {
            if let amount = number(beforeAny: mapping.tokens, in: text) {
                return (amount, mapping.unit)
            }
        }
        return nil
    }

    private static func subjectiveParentState(in text: String) -> ParentSubjectiveState? {
        if containsAny(text, ["我很轻松", "我很輕鬆", "我状态很好", "我狀態很好", "轻松有余", "輕鬆有餘", "i feel relaxed", "i am relaxed", "doing great"]) { return .relaxed }
        if containsAny(text, ["我还行", "我還行", "状态还行", "狀態還行", "我还好", "我還好", "i am okay", "i'm okay", "doing okay", "not bad"]) { return .okay }
        if containsAny(text, ["我有点累", "我有點累", "我累了", "有些累", "i am tired", "i'm tired", "a bit tired"]) { return .tired }
        if containsAny(text, ["身心俱疲", "很疲惫", "很疲憊", "累坏了", "累壞了", "撑不住", "撐不住", "exhausted", "worn out", "completely drained"]) { return .exhausted }
        if containsAny(text, ["需要帮忙", "需要幫忙", "需要帮助", "需要幫助", "帮帮我", "幫幫我", "i need help", "need some help", "need support"]) { return .help }
        return nil
    }

    private static func durationMinutes(in text: String) -> Int? {
        if let hours = number(beforeAny: ["小时", "小時", "个小时", "個小時", "hours", "hour", "hrs", "hr"], in: text) {
            return max(Int((hours * 60).rounded()), 1)
        }
        return integer(beforeAny: ["分钟", "分鐘", "分", "minutes", "minute", "mins", "min"], in: text)
    }

    private static func nursingDurationMinutes(in text: String) -> Int? {
        if let eachSideRange = ["左右各", "兩邊各", "两边各", "both sides", "each side"].compactMap({ text.range(of: $0) }).first {
            let prefix = String(text[..<eachSideRange.lowerBound])
            if let explicitTotal = durationMinutes(in: prefix) {
                return explicitTotal
            }
            let eachSidePattern = "(?:左右\\s*各|兩邊\\s*各|两边\\s*各|both sides?\\s*(?:for|at)?|each side\\s*(?:for|at)?)\\s*(\(numberTokenPattern))\\s*(?:分钟|分鐘|分|minutes|minute|mins|min)"
            if let token = firstCapture(pattern: eachSidePattern, in: text),
               let value = parseNumber(token) {
                return Int((value * 2).rounded())
            }
        }
        return durationMinutes(in: text)
    }

    private static func recordDate(in text: String, referenceDate: Date) -> Date {
        let calendar = Calendar.current
        var baseDate = referenceDate
        if containsAny(text, ["昨天", "昨晚", "昨日", "尋日", "寻日", "yesterday", "last night"]) {
            baseDate = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        }
        if let component = timeComponents(in: text).first,
           let date = date(on: baseDate, component: component, calendar: calendar) {
            return min(date, referenceDate)
        }
        if let minutes = relativeMinutesAgo(in: text) {
            return referenceDate.addingTimeInterval(TimeInterval(-minutes * 60))
        }
        return referenceDate
    }

    private static func sleepWindow(in text: String, referenceDate: Date) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let components = timeComponents(in: text)
        if components.count >= 2 {
            var baseDate = referenceDate
            if containsAny(text, ["昨天", "昨晚", "昨夜", "昨日", "尋日", "寻日", "yesterday", "last night"]) {
                baseDate = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
            }
            guard let start = date(on: baseDate, component: components[0], calendar: calendar),
                  var end = date(on: baseDate, component: components[1], calendar: calendar) else { return nil }
            if end <= start {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            return (start, min(end, referenceDate))
        }
        if let duration = durationMinutes(in: text), duration > 0 {
            if containsAny(text, ["醒了", "刚醒", "醒咗", "睡了", "瞓咗", "woke", "woke up", "slept", "napped"]) {
                return (referenceDate.addingTimeInterval(TimeInterval(-duration * 60)), referenceDate)
            }
        }
        return nil
    }

    private struct VoiceTimeComponent {
        let hour: Int
        let minute: Int
    }

    private static func timeComponents(in text: String) -> [VoiceTimeComponent] {
        // A bare number is usually a quantity (for example 120 ml or 6.8 kg),
        // so only treat it as a clock time when it has a day-period prefix or
        // an explicit time separator.
        let periods = "凌晨|早上|朝早|上午|中午|下午|下晝|傍晚|晚上|夜晚|夜里|昨晚|昨夜"
        let number = "[0-9一二两兩三四五六七八九十]{1,3}"
        let pattern = "(?:(\(periods))?\\s*(\(number))\\s*[:：点點时時]\\s*(\(number))?\\s*(?:分)?\\s*(am|pm)?|(\(periods))\\s*(\(number))|([0-9]{1,2})\\s*(am|pm))"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            let period = capture(match: match, index: 1, in: text)
                ?? capture(match: match, index: 5, in: text)
                ?? ""
            guard let hourToken = capture(match: match, index: 2, in: text)
                    ?? capture(match: match, index: 6, in: text)
                    ?? capture(match: match, index: 7, in: text),
                  let rawHour = parseNumber(hourToken).map({ Int($0) }),
                  (0...23).contains(rawHour) else { return nil }
            let minute = capture(match: match, index: 3, in: text)
                .flatMap(parseNumber)
                .map(Int.init) ?? 0
            guard (0...59).contains(minute) else { return nil }
            var hour = rawHour
            let meridiem = capture(match: match, index: 4, in: text)
                ?? capture(match: match, index: 8, in: text)
                ?? ""
            if (containsAny(period, ["下午", "下晝", "傍晚", "晚上", "夜晚", "夜里", "昨晚", "昨夜"]) || meridiem == "pm"), hour < 12 {
                hour += 12
            } else if period == "中午", hour < 11 {
                hour += 12
            } else if (containsAny(period, ["凌晨", "早上", "朝早", "上午"]) || meridiem == "am"), hour == 12 {
                hour = 0
            }
            return VoiceTimeComponent(hour: hour, minute: minute)
        }
    }

    private static func date(on baseDate: Date, component: VoiceTimeComponent, calendar: Calendar) -> Date? {
        var values = calendar.dateComponents([.year, .month, .day], from: baseDate)
        values.hour = component.hour
        values.minute = component.minute
        values.second = 0
        return calendar.date(from: values)
    }

    private static func relativeMinutesAgo(in text: String) -> Int? {
        let pattern = "(\(numberTokenPattern))\\s*(分钟|分鐘|分|小时|小時|minutes|minute|hours|hour)\\s*(?:前|ago)"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let token = capture(match: match, index: 1, in: text),
              let value = parseNumber(token),
              let unit = capture(match: match, index: 2, in: text) else { return nil }
        return containsAny(unit, ["小时", "小時", "hour"]) ? Int((value * 60).rounded()) : Int(value.rounded())
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) else {
            return nil
        }
        return capture(match: match, index: 1, in: text)
    }

    private static func capture(match: NSTextCheckingResult, index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: text) else { return nil }
        return String(text[range])
    }

    private static func parseNumber(_ token: String) -> Double? {
        let normalizedToken = token.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "點", with: "点")
        if let value = Double(normalizedToken) { return value }
        if normalizedToken == "半" || normalizedToken == "half" { return 0.5 }
        if let value = englishNumber(normalizedToken) { return value }
        if normalizedToken.contains("点") {
            let parts = normalizedToken.split(separator: "点", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let integer = chineseInteger(parts[0]) else { return nil }
            let fractionDigits = parts[1].compactMap { chineseDigit($0) }
            guard fractionDigits.count == parts[1].count else { return nil }
            let fraction = Double(fractionDigits.map(String.init).joined()) ?? 0
            return Double(integer) + fraction / pow(10, Double(fractionDigits.count))
        }
        return chineseInteger(normalizedToken).map(Double.init)
    }

    private static let numberTokenPattern = "(?:[0-9]+(?:\\.[0-9]+)?|[零〇一二两兩三四五六七八九十百千万點点半]+|half|an?|zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|(?:twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)(?:[- ](?:one|two|three|four|five|six|seven|eight|nine))?)"

    private static func englishNumber(_ token: String) -> Double? {
        if token == "a" || token == "an" { return 1 }
        let values: [String: Int] = [
            "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
            "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
            "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
            "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
        ]
        let parts = token.split(separator: " ").map(String.init)
        guard !parts.isEmpty, parts.allSatisfy({ values[$0] != nil }) else { return nil }
        return Double(parts.compactMap { values[$0] }.reduce(0, +))
    }

    private static func chineseInteger(_ token: String) -> Int? {
        guard !token.isEmpty else { return nil }
        if token.allSatisfy({ chineseDigit($0) != nil }) {
            return Int(token.compactMap(chineseDigit).map(String.init).joined())
        }
        var total = 0
        var section = 0
        var number = 0
        for character in token {
            if let digit = chineseDigit(character) {
                number = digit
                continue
            }
            let unit: Int
            switch character {
            case "十": unit = 10
            case "百": unit = 100
            case "千": unit = 1_000
            case "万": unit = 10_000
            default: return nil
            }
            if unit == 10_000 {
                section += number
                total += max(section, 1) * unit
                section = 0
            } else {
                section += max(number, 1) * unit
            }
            number = 0
        }
        return total + section + number
    }

    private static func chineseDigit(_ character: Character) -> Int? {
        switch character {
        case "零", "〇": return 0
        case "一": return 1
        case "二", "两", "兩": return 2
        case "三": return 3
        case "四": return 4
        case "五": return 5
        case "六": return 6
        case "七": return 7
        case "八": return 8
        case "九": return 9
        default: return nil
        }
    }
}

@MainActor
private final class VoiceSpeechRecognizer: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case preparing
        case listening
        case processing
        case failed
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var level: CGFloat = 0.08
    @Published private(set) var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInputTap = false

    var isListening: Bool { phase == .listening }

    func start() async {
        cancel(clearTranscript: true)
        phase = .preparing
        errorMessage = nil

        guard await requestPermissions() else {
            fail(VoiceRecordCopy.permissionDenied)
            return
        }

        let recognitionLocale = VoiceSpeechLocale.preferred(
            language: AppLocalization.language,
            regionalLocale: AppLocalization.locale
        )
        guard let recognizer = SFSpeechRecognizer(locale: recognitionLocale), recognizer.isAvailable else {
            fail(VoiceRecordCopy.recognizerUnavailable)
            return
        }

        #if targetEnvironment(simulator)
        // CoreSimulator can expose a microphone route whose RemoteIO format is
        // still 0 Hz, which causes AVAudioEngine to abort instead of throwing.
        fail(VoiceRecordCopy.simulatorMicrophoneUnavailable)
        return
        #else
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            guard session.sampleRate > 0, !session.currentRoute.inputs.isEmpty else {
                throw VoiceSpeechError.invalidAudioFormat
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Let Speech use the on-device model when available while retaining
            // the system speech-service fallback when that model is unavailable.
            request.requiresOnDeviceRecognition = false
            request.taskHint = .dictation
            request.contextualStrings = Self.careVocabulary(for: recognitionLocale)
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw VoiceSpeechError.invalidAudioFormat
            }
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self, weak request] buffer, _ in
                request?.append(buffer)
                guard let value = Self.normalizedLevel(buffer) else { return }
                Task { @MainActor [weak self] in
                    self?.level = value
                }
            }
            hasInputTap = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        transcript = result.bestTranscription.formattedString
                    }
                    if let error, transcript.isEmpty, phase == .listening {
                        fail(error.localizedDescription)
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            phase = .listening
        } catch {
            stopCapture(cancelTask: true)
            fail(error.localizedDescription)
        }
        #endif
    }

    func stop() async -> String {
        guard phase == .listening else { return transcript }
        phase = .processing
        stopCapture(cancelTask: false)
        try? await Task.sleep(for: .milliseconds(450))
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        level = 0.08
        phase = .idle
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reset() {
        cancel(clearTranscript: true)
    }

    func replaceTranscript(with value: String) {
        transcript = value.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        if phase == .failed {
            phase = .idle
        }
    }

    func cancel(clearTranscript: Bool = false) {
        stopCapture(cancelTask: true)
        if clearTranscript {
            transcript = ""
        }
        errorMessage = nil
        level = 0.08
        phase = .idle
    }

    private func requestPermissions() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            speechStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        } else {
            speechStatus = SFSpeechRecognizer.authorizationStatus()
        }
        guard speechStatus == .authorized else { return false }

        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func stopCapture(cancelTask: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        recognitionRequest?.endAudio()
        if cancelTask {
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static let baseCareVocabulary = [
        "母乳亲喂", "母乳親餵", "亲喂", "親餵", "左右各七分钟", "左右各七分鐘",
        "左边亲喂", "左邊親餵", "右边亲喂", "右邊親餵", "配方奶", "奶粉", "母乳瓶喂",
        "母乳瓶餵", "储奶", "儲奶", "冷藏奶", "冻奶", "凍奶", "毫升", "辅食", "輔食",
        "米糊", "米粉", "果泥", "菜泥", "肉泥", "鸡蛋", "雞蛋", "蛋黄", "蛋黃", "酸奶",
        "拉屎", "拉粑粑", "拉臭臭", "便便", "大便", "稀便", "水样便", "水樣便", "黏液便",
        "硬结便", "成型便", "糊状便", "尿布", "尿湿", "尿濕", "尿尿", "嘘嘘", "噓噓",
        "小睡", "夜睡", "刚睡着", "剛睡著", "刚醒", "剛醒", "排气操", "排氣操", "拍嗝",
        "趴卧", "趴臥", "趴趴", "翻身训练", "翻身訓練", "黑白卡", "追物训练", "追物訓練",
        "抓握", "健身架", "悬挂玩具", "懸掛玩具", "对视聊天", "對視聊天", "照镜子", "照鏡子",
        "绘本", "繪本", "布书", "布書", "音乐律动", "音樂律動", "听儿歌", "聽兒歌",
        "户外活动", "戶外活動", "室内活动", "室內活動", "抚触", "撫觸", "飞机抱", "飛機抱",
        "洗澡", "剪指甲", "刷牙", "体重", "體重", "身高", "身长", "身長", "公斤", "厘米",
        "好奇探索", "开心满足", "開心滿足", "平静安稳", "平靜安穩", "有点烦躁", "有點煩躁",
        "正在哭闹", "正在哭鬧", "困倦想睡", "轻松有余", "輕鬆有餘", "状态还行", "狀態還行",
        "有些累了", "身心俱疲", "需要帮忙", "需要幫忙"
    ]

    private static func careVocabulary(for locale: Locale) -> [String] {
        let identifier = locale.identifier.lowercased().replacingOccurrences(of: "_", with: "-")
        let regionalVocabulary: [String]
        if identifier.hasPrefix("zh-hk") {
            regionalVocabulary = [
                "尿片濕咗", "尿咗少少", "尿咗唔少", "尿咗好多", "濕片", "瀨咗尿", "屙咗尿",
                "便咗", "屙咗便便", "食咗奶", "飲咗奶", "奶樽", "人奶", "埋身餵", "兩邊各七分鐘",
                "朝早", "下晝", "夜晚", "瞓咗", "瞓到", "醒咗", "眼瞓", "扭計", "喊緊"
            ]
        } else if identifier.hasPrefix("zh-tw") {
            regionalVocabulary = [
                "尿尿了", "尿了一點點", "尿了不少", "尿了很多", "尿布濕了", "尿布濕濕的", "小便了",
                "母奶", "親餵", "瓶餵", "兩邊各七分鐘", "配方奶", "副食品", "米精", "麥精",
                "睡著了", "睡醒了", "趴睡練習", "翻身練習", "繪本時間", "換尿布"
            ]
        } else if identifier.hasPrefix("zh") {
            // Includes Mainland China and Singapore Simplified Chinese usage.
            regionalVocabulary = [
                "尿尿了", "尿了一点点", "尿了不少", "尿了很多", "尿片湿了", "尿布湿湿的", "小便了", "wee wee",
                "喝奶", "吃奶", "母乳瓶喂", "配方奶", "亲喂", "左右各七分钟", "辅食", "米糊",
                "睡着了", "睡醒了", "趴趴", "翻身训练", "绘本时间", "换尿布"
            ]
        } else if identifier.hasPrefix("en-gb") || identifier.hasPrefix("en-sg") {
            regionalVocabulary = englishBaseVocabulary + [
                "wet nappy", "slightly wet nappy", "quite wet nappy", "soaking wet nappy", "heavy nappy",
                "did a wee", "had a wee", "small wee", "big wee", "did a poo", "dirty nappy",
                "millilitres", "expressed breast milk", "breast-fed", "weaning food", "yoghurt",
                "winded the baby", "had a bath", "tiger in the tree hold"
            ]
        } else {
            regionalVocabulary = englishBaseVocabulary + [
                "wet diaper", "slightly wet diaper", "pretty wet diaper", "soaked diaper", "heavy diaper",
                "peed", "a little pee", "a lot of pee", "pooped", "dirty diaper",
                "milliliters", "fluid ounces", "pumped milk", "breastfed", "baby cereal",
                "burped the baby", "gave the baby a bath", "airplane hold"
            ]
        }
        return baseCareVocabulary + regionalVocabulary
    }

    private static let englishBaseVocabulary = [
        "formula", "bottle feeding", "breast milk", "nursing", "both sides", "left breast", "right breast",
        "solid food", "rice cereal", "puree", "porridge", "tummy time", "rolling practice", "contrast cards",
        "visual tracking", "grasping practice", "play gym", "mirror play", "story time", "nursery rhymes",
        "baby massage", "bicycle legs", "went for a walk", "trimmed nails", "brushed teeth",
        "fell asleep", "woke up", "nap", "weight", "height", "happy", "calm", "fussy", "crying", "sleepy",
        "I am tired", "I am exhausted", "I need help"
    ]

    private func fail(_ message: String) {
        errorMessage = message
        phase = .failed
        level = 0.08
    }

    nonisolated private static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> CGFloat? {
        guard let channel = buffer.floatChannelData?.pointee else { return nil }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return nil }
        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(count))
        let decibels = 20 * log10(max(rms, 0.000_001))
        return min(max(CGFloat((decibels + 55) / 55), 0.08), 1)
    }
}

private enum VoiceSpeechError: LocalizedError {
    case invalidAudioFormat

    var errorDescription: String? {
        VoiceRecordCopy.microphoneUnavailable
    }
}

struct VoiceRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @EnvironmentObject private var easyCycleStore: EasyCycleStore

    @StateObject private var speech = VoiceSpeechRecognizer()
    @State private var pendingDraft: VoiceRecordDraft?
    @State private var parseError: String?
    @State private var suggestionIndex = 0
    @State private var savedCount = 0
    @State private var showSavedConfirmation = false
    @State private var didStartAutomatically = false
    @State private var isEditingTranscript = false
    @State private var isApplyingTranscriptEdit = false
    @State private var transcriptDraft = ""
    @State private var structuredEditorDraft: VoiceRecordDraft?
    @State private var isChoosingRecordType = false
    @FocusState private var transcriptEditorFocused: Bool

    private let suggestions = VoiceRecordCopy.suggestions

    private var hasModalOverlay: Bool {
        pendingDraft != nil || structuredEditorDraft != nil || isChoosingRecordType
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Spacer(minLength: 24)
                promptContent
                Spacer(minLength: 24)
                statusContent
                controls
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .allowsHitTesting(!hasModalOverlay)

            if let pendingDraft {
                confirmationOverlay(draft: pendingDraft)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(3)
            }

            if let structuredEditorDraft {
                structuredEditor(for: structuredEditorDraft)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(4)
            }

            if isChoosingRecordType {
                recordTypeChooser
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(5)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: pendingDraft != nil)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                speech.cancel()
            }
        }
        .onChange(of: speech.transcript) { _, newValue in
            if !isEditingTranscript {
                transcriptDraft = newValue
            }
        }
        .task {
            guard !didStartAutomatically else { return }
            didStartAutomatically = true
            await speech.start()
        }
        .onDisappear {
            speech.cancel()
        }
        .toolbar {
            if isEditingTranscript {
                ToolbarItemGroup(placement: .keyboard) {
                    Button(VoiceRecordCopy.cancelEdit) {
                        cancelTranscriptEditing()
                    }
                    Spacer()
                    Button(VoiceRecordCopy.convertEditedText) {
                        applyTranscriptEdit()
                    }
                    .fontWeight(.bold)
                    .disabled(isApplyingTranscriptEdit)
                }
            }
        }
        .interactiveDismissDisabled(
            speech.isListening || pendingDraft != nil || structuredEditorDraft != nil || isChoosingRecordType
        )
    }

    private var background: some View {
        ZStack {
            DesignToken.canvas
            Circle()
                .fill(DesignToken.easyEatSoft.opacity(0.72))
                .frame(width: 310, height: 310)
                .blur(radius: 12)
                .offset(x: 150, y: -330)
            Circle()
                .fill(DesignToken.easySleepSoft.opacity(0.78))
                .frame(width: 280, height: 280)
                .blur(radius: 16)
                .offset(x: -150, y: 330)
            LinearGradient(
                colors: [DesignToken.surface.opacity(0.08), DesignToken.primarySoft.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            AppPageStandaloneButton(
                systemName: "xmark",
                accessibilityLabel: VoiceRecordCopy.close,
                action: close
            )
            Spacer()
            VStack(spacing: 2) {
                Text(VoiceRecordCopy.title)
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                if savedCount > 0 {
                    Text(VoiceRecordCopy.savedCount(savedCount))
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(DesignToken.successText)
                }
            }
            Spacer()
            Color.clear.frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
        }
        .padding(.top, 10)
    }

    private var promptContent: some View {
        VStack(spacing: 18) {
            Text(speech.transcript.isEmpty ? VoiceRecordCopy.trySaying : VoiceRecordCopy.recognizedText)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.primary)
                .padding(.horizontal, 13)
                .frame(height: 30)
                .background(Capsule().fill(DesignToken.primary.opacity(0.10)))

            if isEditingTranscript {
                VStack(spacing: 10) {
                    TextEditor(text: $transcriptDraft)
                        .font(BBBFont.font(size: 22, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .multilineTextAlignment(.leading)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(maxWidth: 360, minHeight: 132, maxHeight: 190)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(DesignToken.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(DesignToken.primary.opacity(0.30), lineWidth: 1.5)
                        )
                        .focused($transcriptEditorFocused)
                        .accessibilityLabel(VoiceRecordCopy.editTranscript)
                        .accessibilityIdentifier("voice-record-transcript-editor")

                    Text(VoiceRecordCopy.editTranscriptHint)
                        .font(BBBFont.font(size: 11.5, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
            } else {
                Button(action: beginTranscriptEditing) {
                    VStack(spacing: 8) {
                        Text(displayText)
                            .font(BBBFont.font(size: displayText.count > 34 ? 25 : 31, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: 340, minHeight: 132)
                            .contentTransition(.numericText())

                        if !speech.transcript.isEmpty {
                            Label(VoiceRecordCopy.tapToEdit, systemImage: "pencil")
                                .font(BBBFont.font(size: 11.5, weight: .heavy))
                                .foregroundStyle(DesignToken.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(speech.transcript.isEmpty || speech.phase == .preparing || speech.phase == .processing)
                .accessibilityLabel(VoiceRecordCopy.editTranscript)
            }

            if showSavedConfirmation {
                Label(VoiceRecordCopy.savedContinue, systemImage: "checkmark.circle.fill")
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.successText)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Capsule().fill(DesignToken.successSoft))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let message = speech.errorMessage ?? parseError {
                VStack(spacing: 10) {
                    Text(message)
                        .font(BBBFont.font(size: 13, weight: .semibold))
                        .foregroundStyle(DesignToken.errorText)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        if speech.errorMessage == VoiceRecordCopy.permissionDenied {
                            Button(VoiceRecordCopy.openSettings) {
                                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                                openURL(settingsURL)
                            }
                        }
                        Button(VoiceRecordCopy.keyboardInput) {
                            beginTranscriptEditing()
                        }
                        Button(VoiceRecordCopy.manualRecord) {
                            openManualEditor()
                        }
                    }
                    .font(BBBFont.font(size: 12.5, weight: .heavy))
                    .buttonStyle(.bordered)
                    .tint(DesignToken.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignToken.errorSoft)
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var displayText: String {
        if !speech.transcript.isEmpty {
            return "“\(speech.transcript)”"
        }
        return "“\(suggestions[suggestionIndex % suggestions.count])”"
    }

    private var statusContent: some View {
        VStack(spacing: 5) {
            Text(statusTitle)
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            Text(statusSubtitle)
                .font(BBBFont.font(size: 12.5, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 14)
    }

    private var statusTitle: String {
        if isEditingTranscript { return VoiceRecordCopy.editingTranscript }
        switch speech.phase {
        case .idle, .failed: return VoiceRecordCopy.sayWhatToRecord
        case .preparing: return VoiceRecordCopy.preparing
        case .listening: return VoiceRecordCopy.listening
        case .processing: return VoiceRecordCopy.converting
        }
    }

    private var statusSubtitle: String {
        if isEditingTranscript { return VoiceRecordCopy.editThenConvert }
        switch speech.phase {
        case .listening: return VoiceRecordCopy.tapStop
        case .processing, .preparing: return VoiceRecordCopy.pleaseWait
        case .idle, .failed: return VoiceRecordCopy.previewFirst
        }
    }

    private var controls: some View {
        Group {
            if isEditingTranscript {
                transcriptEditingControls
            } else {
                recordingControls
            }
        }
    }

    private var transcriptEditingControls: some View {
        HStack(spacing: 10) {
            Button(VoiceRecordCopy.cancelEdit) {
                cancelTranscriptEditing()
            }
            .foregroundStyle(DesignToken.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignToken.surfaceRaised)
            )

            Button(VoiceRecordCopy.convertEditedText) {
                applyTranscriptEdit()
            }
            .foregroundStyle(DesignToken.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignToken.primary)
            )
            .disabled(
                transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isApplyingTranscriptEdit
            )
            .accessibilityIdentifier("voice-record-convert-edited-text")
        }
        .font(BBBFont.font(size: 14, weight: .heavy))
        .buttonStyle(.plain)
    }

    private var recordingControls: some View {
        HStack(spacing: 16) {
            Button(action: reset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(DesignToken.surfaceRaised))
                    .overlay(Circle().stroke(DesignToken.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(VoiceRecordCopy.reset)

            VoiceRecordWaveform(
                level: speech.level,
                isActive: speech.isListening,
                reduceMotion: reduceMotion
            )
            .frame(maxWidth: .infinity)

            Button(action: microphoneAction) {
                ZStack {
                    Circle()
                        .fill(speech.isListening ? DesignToken.easySleep : DesignToken.primary)
                        .shadow(color: DesignToken.primary.opacity(0.22), radius: 18, y: 8)
                    if speech.phase == .preparing || speech.phase == .processing {
                        ProgressView()
                            .tint(DesignToken.onPrimary)
                    } else {
                        Image(systemName: speech.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(DesignToken.onPrimary)
                    }
                }
                .frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)
            .disabled(speech.phase == .preparing || speech.phase == .processing)
            .accessibilityLabel(speech.isListening ? VoiceRecordCopy.stop : VoiceRecordCopy.start)
        }
    }

    private func confirmationOverlay(draft: VoiceRecordDraft) -> some View {
        ZStack {
            DesignToken.scrim.opacity(0.28)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: draft.icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(DesignToken.onPrimary)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(draft.color))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(VoiceRecordCopy.convertedRecord)
                            .font(BBBFont.font(size: 12, weight: .heavy))
                            .foregroundStyle(DesignToken.textSecondary)
                        Text(draft.title.localized)
                            .font(BBBFont.font(size: 20, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(draft.summary)
                        .font(BBBFont.font(size: 28, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .minimumScaleFactor(0.72)
                    Label(AppDateTimeFormat.dateTime(draft.recordedAt), systemImage: "clock.fill")
                        .font(BBBFont.font(size: 13, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(draft.color.opacity(0.10))
                )

                Button {
                    editTranscriptFromConfirmation()
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text("“\(speech.transcript)”")
                            .font(BBBFont.font(size: 12, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DesignToken.primary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignToken.surfaceSoft)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(VoiceRecordCopy.editTranscript)

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button(VoiceRecordCopy.editTranscript) {
                            editTranscriptFromConfirmation()
                        }
                        .foregroundStyle(DesignToken.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(DesignToken.surfaceSoft)
                        )
                        .accessibilityIdentifier("voice-record-edit-transcript")

                        Button(VoiceRecordCopy.editRecord) {
                            isChoosingRecordType = true
                        }
                        .foregroundStyle(DesignToken.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(DesignToken.surfaceSoft)
                        )
                        .accessibilityIdentifier("voice-record-edit-record")
                    }

                    Button(VoiceRecordCopy.confirmSave) {
                        confirmSave(draft)
                    }
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(draft.color)
                    )
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("voice-record-confirm-save")

                    Button(VoiceRecordCopy.retry) {
                        pendingDraft = nil
                        resetAndListen()
                    }
                    .foregroundStyle(DesignToken.textSecondary)
                    .accessibilityIdentifier("voice-record-retry")
                }
                .font(BBBFont.font(size: 14, weight: .heavy))
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignToken.surface)
                    .shadow(color: DesignToken.shadowColor.opacity(0.20), radius: 28, y: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(0.8), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    private func microphoneAction() {
        parseError = nil
        showSavedConfirmation = false
        if speech.isListening {
            Task {
                let text = await speech.stop()
                parse(text)
            }
        } else {
            Task { await speech.start() }
        }
    }

    @discardableResult
    private func parse(_ text: String) -> Bool {
        switch VoiceRecordParser.parse(text) {
        case .success(let draft):
            pendingDraft = draft
            parseError = nil
            return true
        case .failure(let error):
            parseError = error.message
            return false
        }
    }

    private func beginTranscriptEditing() {
        guard speech.phase != .preparing && speech.phase != .processing else { return }
        parseError = nil
        showSavedConfirmation = false
        if speech.isListening {
            Task {
                let text = await speech.stop()
                openTranscriptEditor(with: text)
            }
        } else {
            openTranscriptEditor(with: speech.transcript)
        }
    }

    private func openTranscriptEditor(with text: String) {
        transcriptDraft = text
        isEditingTranscript = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            transcriptEditorFocused = true
        }
    }

    private func editTranscriptFromConfirmation() {
        pendingDraft = nil
        openTranscriptEditor(with: speech.transcript)
    }

    private func cancelTranscriptEditing() {
        endTranscriptEditing()
        transcriptDraft = speech.transcript
        parseError = nil
    }

    private func applyTranscriptEdit() {
        let edited = transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !edited.isEmpty, !isApplyingTranscriptEdit else { return }
        speech.replaceTranscript(with: edited)
        switch VoiceRecordParser.parse(edited) {
        case .success(let draft):
            isApplyingTranscriptEdit = true
            parseError = nil
            endTranscriptEditing()

            // Let SwiftUI remove the TextEditor and UIKit resign its first
            // responder before installing the full-screen confirmation layer.
            // Presenting both in one update can leave the retired editor or
            // keyboard transition consuming taps on the save button.
            Task { @MainActor in
                await Task.yield()
                pendingDraft = draft
                isApplyingTranscriptEdit = false
            }
        case .failure(let error):
            parseError = error.message
        }
    }

    private func endTranscriptEditing() {
        transcriptEditorFocused = false
        isEditingTranscript = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func confirmSave(_ draft: VoiceRecordDraft) {
        endTranscriptEditing()
        save(draft)
    }

    private func openManualEditor() {
        if speech.isListening {
            speech.cancel()
        }
        endTranscriptEditing()
        isChoosingRecordType = true
    }

    private var recordTypeChooser: some View {
        ZStack {
            DesignToken.scrim.opacity(0.30)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(VoiceRecordCopy.chooseRecordProject)
                            .font(BBBFont.font(size: 20, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(VoiceRecordCopy.chooseRecordProjectHint)
                            .font(BBBFont.font(size: 11.5, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                    }
                    Spacer()
                    Button {
                        isChoosingRecordType = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(DesignToken.surfaceSoft))
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(VoiceRecordEditorKind.allCases) { kind in
                        Button {
                            chooseRecordEditor(kind)
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: kind.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(kind.color)
                                Text(kind.title)
                                    .font(BBBFont.font(size: 11.5, weight: .heavy))
                                    .foregroundStyle(DesignToken.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(kind.color.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignToken.surface)
                    .shadow(color: DesignToken.shadowColor.opacity(0.20), radius: 28, y: 14)
            )
            .padding(.horizontal, 20)
        }
    }

    private func chooseRecordEditor(_ kind: VoiceRecordEditorKind) {
        let source = transcriptDraft.isEmpty ? speech.transcript : transcriptDraft
        let inferredDraft = pendingDraft ?? VoiceRecordParser.fallbackDraft(for: source)
        isChoosingRecordType = false
        structuredEditorDraft = kind.draft(preserving: inferredDraft)
    }

    @ViewBuilder
    private func structuredEditor(for draft: VoiceRecordDraft) -> some View {
        switch draft {
        case .growth:
            VoiceGrowthDraftEditor(
                draft: draft,
                onCancel: { structuredEditorDraft = nil },
                onSave: { revisedDraft in
                    structuredEditorDraft = nil
                    save(revisedDraft)
                }
            )
        case .solid:
            VoiceSolidDraftEditor(
                draft: draft,
                onCancel: { structuredEditorDraft = nil },
                onSave: { revisedDraft in
                    structuredEditorDraft = nil
                    save(revisedDraft)
                }
            )
        case .subjective:
            VoiceSubjectiveDraftEditor(
                draft: draft,
                onCancel: { structuredEditorDraft = nil },
                onSave: { revisedDraft in
                    structuredEditorDraft = nil
                    save(revisedDraft)
                }
            )
        default:
            QuickRecordCardOverlay(
                voiceDraft: draft,
                onDismiss: { structuredEditorDraft = nil },
                onCompletedRecord: { _ in
                    completeStructuredSave()
                }
            )
        }
    }

    private func completeStructuredSave() {
        pendingDraft = nil
        structuredEditorDraft = nil
        savedCount += 1
        showSavedConfirmation = true
        speech.reset()
        transcriptDraft = ""
        suggestionIndex = (suggestionIndex + 1) % suggestions.count
        parseError = nil
    }

    private func save(_ draft: VoiceRecordDraft) {
        AppHapticFeedback.impact(.medium)
        switch draft {
        case .feeding(let kind, let amount, let recordedAt):
            let entries: [FeedingEntry]
            switch kind {
            case .formula:
                entries = [FeedingEntry(type: .bottle, milkType: .formula, bottleAmount: amount)]
            case .expressed:
                entries = [FeedingEntry(type: .bottle, milkType: .expressed, bottleAmount: amount)]
            case .nursing:
                let leftMinutes = amount / 2
                let rightMinutes = amount - leftMinutes
                entries = [
                    FeedingEntry(type: .breast, breastMode: .nursing, breastSide: .left, breastDuration: leftMinutes),
                    FeedingEntry(type: .breast, breastMode: .nursing, breastSide: .right, breastDuration: rightMinutes)
                ].filter { ($0.breastDuration ?? 0) > 0 }
            case .solids:
                entries = [FeedingEntry(type: .solid, solidFood: .rice, solidAmount: Double(amount), solidUnit: .g)]
            }
            feedingStore.saveSession(FeedingSession(entries: entries, notes: "", babyMood: .happy, createdAt: recordedAt))
        case .solid(let food, let amount, let unit, let recordedAt):
            let entry = FeedingEntry(
                type: .solid,
                solidFood: food,
                solidAmount: amount,
                solidUnit: unit
            )
            feedingStore.saveSession(FeedingSession(entries: [entry], notes: "", babyMood: .happy, createdAt: recordedAt))
        case .diaper(let kind, let recordedAt):
            _ = activityStore.recordDiaper(
                type: kind.isPee ? DiaperRecordType.pee.rawValue : DiaperRecordType.poop.rawValue,
                detail: kind.detail,
                note: "",
                recordedAt: recordedAt
            )
        case .activity(let title, let durationMinutes, let recordedAt):
            if let durationMinutes {
                _ = activityStore.recordActivity(title: title, durationMinutes: durationMinutes, recordedAt: recordedAt)
            } else {
                _ = activityStore.recordActivity(title: title, recordedAt: recordedAt)
            }
        case .sleep(let startAt, let endAt):
            _ = activityStore.recordSleep(startTime: startAt, endTime: endAt, note: "")
        case .growth(let kind, let value, let recordedAt):
            growthMetricStore.saveRecord(kind: kind, value: value, recordedAt: recordedAt)
        case .subjective(let babyState, let parentState, let recordedAt):
            SubjectiveStateStore.shared.save(
                context: .manual(at: recordedAt),
                babyState: babyState,
                parentState: parentState
            )
        }

        easyCycleStore.rebuild(
            from: feedingStore.allSessions,
            careRecords: activityStore.exportCareRecords()
        )
        pendingDraft = nil
        savedCount += 1
        showSavedConfirmation = true
        speech.reset()
        transcriptDraft = ""
        suggestionIndex = (suggestionIndex + 1) % suggestions.count
        parseError = nil
    }

    private func reset() {
        speech.reset()
        pendingDraft = nil
        parseError = nil
        showSavedConfirmation = false
        isEditingTranscript = false
        isApplyingTranscriptEdit = false
        transcriptEditorFocused = false
        transcriptDraft = ""
        suggestionIndex = (suggestionIndex + 1) % suggestions.count
    }

    private func resetAndListen() {
        reset()
        Task { await speech.start() }
    }

    private func close() {
        speech.cancel()
        dismiss()
    }
}

private struct VoiceSolidDraftEditor: View {
    let onCancel: () -> Void
    let onSave: (VoiceRecordDraft) -> Void

    @State private var food: SolidFood
    @State private var amountText: String
    @State private var unit: SolidUnit
    @State private var recordedAt: Date
    @FocusState private var amountFocused: Bool

    private let availableUnits: [SolidUnit] = [.g, .ml, .tsp, .tbsp, .piece]

    init(
        draft: VoiceRecordDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (VoiceRecordDraft) -> Void
    ) {
        self.onCancel = onCancel
        self.onSave = onSave
        if case .solid(let food, let amount, let unit, let recordedAt) = draft {
            _food = State(initialValue: food)
            _amountText = State(initialValue: VoiceRecordParser.numberText(amount))
            _unit = State(initialValue: unit)
            _recordedAt = State(initialValue: recordedAt)
        } else {
            _food = State(initialValue: .other)
            _amountText = State(initialValue: "30")
            _unit = State(initialValue: .g)
            _recordedAt = State(initialValue: Date())
        }
    }

    var body: some View {
        ZStack {
            DesignToken.scrim.opacity(0.30).ignoresSafeArea().allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(VoiceRecordCopy.editSolidRecord)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)

                    Picker(VoiceRecordCopy.solidFood, selection: $food) {
                        ForEach(SolidFood.allCases) { item in
                            Text("\(item.emoji) \(item.localizedDisplayName)").tag(item)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField(VoiceRecordCopy.value, text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .focused($amountFocused)

                        Picker(VoiceRecordCopy.unit, selection: $unit) {
                            ForEach(availableUnits) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        .frame(maxWidth: 118)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DesignToken.easyEatSoft)
                    )

                    DatePicker(
                        VoiceRecordCopy.recordTime,
                        selection: $recordedAt,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    HStack(spacing: 10) {
                        Button(VoiceRecordCopy.cancelEdit, action: onCancel)
                            .foregroundStyle(DesignToken.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(DesignToken.surfaceSoft)
                            )

                        Button(VoiceRecordCopy.confirmSave) {
                            guard let amount else { return }
                            onSave(.solid(
                                food: food,
                                amount: amount,
                                unit: unit,
                                recordedAt: min(recordedAt, Date())
                            ))
                        }
                        .foregroundStyle(DesignToken.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(canSave ? DesignToken.easyEat : DesignToken.textFaint)
                        )
                        .disabled(!canSave)
                    }
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .frame(maxHeight: 560)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignToken.surface)
                    .shadow(color: DesignToken.shadowColor.opacity(0.20), radius: 28, y: 14)
            )
            .padding(.horizontal, 20)
        }
        .onAppear { amountFocused = true }
    }

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let amount, amount.isFinite else { return false }
        return amount > 0 && amount <= 2_000
    }
}

private struct VoiceGrowthDraftEditor: View {
    let onCancel: () -> Void
    let onSave: (VoiceRecordDraft) -> Void

    @State private var kind: GrowthMetricKind
    @State private var valueText: String
    @State private var recordedAt: Date
    @FocusState private var valueFocused: Bool

    init(
        draft: VoiceRecordDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (VoiceRecordDraft) -> Void
    ) {
        self.onCancel = onCancel
        self.onSave = onSave
        if case .growth(let kind, let value, let recordedAt) = draft {
            _kind = State(initialValue: kind)
            _valueText = State(initialValue: VoiceRecordParser.numberText(value))
            _recordedAt = State(initialValue: recordedAt)
        } else {
            _kind = State(initialValue: .weight)
            _valueText = State(initialValue: "7")
            _recordedAt = State(initialValue: Date())
        }
    }

    var body: some View {
        ZStack {
            DesignToken.scrim.opacity(0.30)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(VoiceRecordCopy.editRecord)
                            .font(BBBFont.font(size: 20, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(VoiceRecordCopy.editRecordHint)
                            .font(BBBFont.font(size: 11.5, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                    }
                    Spacer()
                }

                Picker(VoiceRecordCopy.recordProject, selection: $kind) {
                    ForEach(GrowthMetricKind.allCases) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField(VoiceRecordCopy.value, text: $valueText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .focused($valueFocused)
                        .accessibilityLabel(VoiceRecordCopy.value)
                    Text(kind.unit)
                        .font(BBBFont.font(size: 16, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(kind.accent.opacity(0.10))
                )

                DatePicker(
                    VoiceRecordCopy.recordTime,
                    selection: $recordedAt,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(BBBFont.font(size: 13, weight: .semibold))

                HStack(spacing: 10) {
                    Button(VoiceRecordCopy.cancelEdit, action: onCancel)
                        .foregroundStyle(DesignToken.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignToken.surfaceSoft)
                        )

                    Button(VoiceRecordCopy.confirmSave) {
                        guard let value = parsedValue else { return }
                        onSave(.growth(kind: kind, value: value, recordedAt: min(recordedAt, Date())))
                    }
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(canSave ? kind.accent : DesignToken.textFaint)
                    )
                    .disabled(!canSave)
                }
                .font(BBBFont.font(size: 14, weight: .heavy))
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignToken.surface)
                    .shadow(color: DesignToken.shadowColor.opacity(0.20), radius: 28, y: 14)
            )
            .padding(.horizontal, 20)
        }
        .onAppear { valueFocused = true }
    }

    private var parsedValue: Double? {
        Double(valueText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let parsedValue, parsedValue.isFinite else { return false }
        return kind.validRange.contains(parsedValue)
    }
}

private struct VoiceSubjectiveDraftEditor: View {
    let onCancel: () -> Void
    let onSave: (VoiceRecordDraft) -> Void

    @State private var babyState: BabySubjectiveState?
    @State private var parentState: ParentSubjectiveState?
    @State private var recordedAt: Date

    init(
        draft: VoiceRecordDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (VoiceRecordDraft) -> Void
    ) {
        self.onCancel = onCancel
        self.onSave = onSave
        if case .subjective(let babyState, let parentState, let recordedAt) = draft {
            _babyState = State(initialValue: babyState)
            _parentState = State(initialValue: parentState)
            _recordedAt = State(initialValue: recordedAt)
        } else {
            _babyState = State(initialValue: nil)
            _parentState = State(initialValue: nil)
            _recordedAt = State(initialValue: Date())
        }
    }

    var body: some View {
        ZStack {
            DesignToken.scrim.opacity(0.30).ignoresSafeArea().allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(VoiceRecordCopy.editSubjectiveState)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)

                    stateSection(
                        title: VoiceRecordCopy.babyState,
                        items: BabySubjectiveState.allCases,
                        selection: $babyState,
                        label: { $0.title },
                        emoji: { $0.emoji }
                    )

                    stateSection(
                        title: VoiceRecordCopy.parentState,
                        items: ParentSubjectiveState.allCases,
                        selection: $parentState,
                        label: { $0.title },
                        emoji: { _ in "♡" }
                    )

                    DatePicker(
                        VoiceRecordCopy.recordTime,
                        selection: $recordedAt,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(BBBFont.font(size: 13, weight: .semibold))

                    HStack(spacing: 10) {
                        Button(VoiceRecordCopy.cancelEdit, action: onCancel)
                            .foregroundStyle(DesignToken.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(DesignToken.surfaceSoft)
                            )

                        Button(VoiceRecordCopy.confirmSave) {
                            onSave(.subjective(
                                babyState: babyState,
                                parentState: parentState,
                                recordedAt: min(recordedAt, Date())
                            ))
                        }
                        .foregroundStyle(DesignToken.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(canSave ? DesignToken.easyYearning : DesignToken.textFaint)
                        )
                        .disabled(!canSave)
                    }
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .frame(maxHeight: 660)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignToken.surface)
                    .shadow(color: DesignToken.shadowColor.opacity(0.20), radius: 28, y: 14)
            )
            .padding(.horizontal, 20)
        }
    }

    private var canSave: Bool { babyState != nil || parentState != nil }

    private func stateSection<Item: Identifiable & Hashable>(
        title: String,
        items: [Item],
        selection: Binding<Item?>,
        label: @escaping (Item) -> String,
        emoji: @escaping (Item) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(items) { item in
                    let isSelected = selection.wrappedValue == item
                    Button {
                        selection.wrappedValue = isSelected ? nil : item
                    } label: {
                        VStack(spacing: 4) {
                            Text(emoji(item)).font(.system(size: 20))
                            Text(label(item))
                                .font(BBBFont.font(size: 10, weight: .bold))
                                .foregroundStyle(DesignToken.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(isSelected ? DesignToken.easyYearningSoft : DesignToken.surfaceSoft)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(isSelected ? DesignToken.easyYearning : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private enum VoiceRecordEditorKind: String, CaseIterable, Identifiable {
    case formula
    case expressed
    case nursing
    case solids
    case diaper
    case activity
    case sleep
    case weight
    case height
    case subjective

    var id: String { rawValue }

    var title: String {
        switch self {
        case .formula: return VoiceRecordCopy.formula
        case .expressed: return VoiceRecordCopy.expressed
        case .nursing: return VoiceRecordCopy.nursing
        case .solids: return VoiceRecordCopy.solids
        case .diaper: return VoiceRecordCopy.diaper
        case .activity: return VoiceRecordCopy.activity
        case .sleep: return VoiceRecordCopy.sleep
        case .weight: return GrowthMetricKind.weight.title
        case .height: return GrowthMetricKind.height.title
        case .subjective: return VoiceRecordCopy.subjectiveState
        }
    }

    var icon: String {
        switch self {
        case .formula, .expressed: return "baby.bottle.fill"
        case .nursing: return "heart.fill"
        case .solids: return "fork.knife"
        case .diaper: return "drop.fill"
        case .activity: return "sparkles"
        case .sleep: return "moon.zzz.fill"
        case .weight: return GrowthMetricKind.weight.icon
        case .height: return GrowthMetricKind.height.icon
        case .subjective: return "heart.text.square.fill"
        }
    }

    var color: Color {
        switch self {
        case .formula, .expressed, .nursing, .solids: return DesignToken.easyEat
        case .diaper, .activity: return DesignToken.easyActivity
        case .sleep: return DesignToken.easySleep
        case .weight: return GrowthMetricKind.weight.accent
        case .height: return GrowthMetricKind.height.accent
        case .subjective: return DesignToken.easyYearning
        }
    }

    func draft(preserving current: VoiceRecordDraft) -> VoiceRecordDraft {
        let date = current.recordedAt
        switch self {
        case .formula:
            return .feeding(kind: .formula, amount: current.feedingAmount ?? 120, recordedAt: date)
        case .expressed:
            return .feeding(kind: .expressed, amount: current.feedingAmount ?? 120, recordedAt: date)
        case .nursing:
            return .feeding(kind: .nursing, amount: current.feedingAmount ?? 15, recordedAt: date)
        case .solids:
            if case .solid(let food, let amount, let unit, _) = current {
                return .solid(food: food, amount: amount, unit: unit, recordedAt: date)
            }
            return .solid(
                food: .other,
                amount: Double(current.feedingAmount ?? 30),
                unit: .g,
                recordedAt: date
            )
        case .diaper:
            if case .diaper(let kind, _) = current {
                return .diaper(kind: kind, recordedAt: date)
            }
            return .diaper(kind: .peeMedium, recordedAt: date)
        case .activity:
            if case .activity(let title, let duration, _) = current {
                return .activity(title: title, durationMinutes: duration, recordedAt: date)
            }
            return .activity(title: VoiceRecordCopy.genericActivity, durationMinutes: nil, recordedAt: date)
        case .sleep:
            if case .sleep(let startAt, let endAt) = current {
                return .sleep(startAt: startAt, endAt: endAt)
            }
            return .sleep(startAt: min(date, Date()).addingTimeInterval(-30 * 60), endAt: min(date, Date()))
        case .weight:
            return .growth(kind: .weight, value: current.growthValue(for: .weight) ?? 7, recordedAt: date)
        case .height:
            return .growth(kind: .height, value: current.growthValue(for: .height) ?? 65, recordedAt: date)
        case .subjective:
            if case .subjective(let babyState, let parentState, _) = current {
                return .subjective(babyState: babyState, parentState: parentState, recordedAt: date)
            }
            return .subjective(babyState: nil, parentState: nil, recordedAt: date)
        }
    }
}

private extension VoiceRecordDraft {
    var feedingAmount: Int? {
        guard case .feeding(_, let amount, _) = self else { return nil }
        return amount
    }

    func growthValue(for kind: GrowthMetricKind) -> Double? {
        guard case .growth(let currentKind, let value, _) = self,
              currentKind == kind,
              kind.validRange.contains(value) else { return nil }
        return value
    }
}

private struct VoiceRecordWaveform: View {
    let level: CGFloat
    let isActive: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 0.08, paused: !isActive)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<22, id: \.self) { index in
                    let wave = (sin(time * 8 + Double(index) * 0.62) + 1) / 2
                    Capsule()
                        .fill(isActive ? DesignToken.primary : DesignToken.textFaint.opacity(0.34))
                        .frame(width: 3.5, height: isActive ? 8 + 24 * level * wave : 8)
                }
            }
            .frame(height: 38)
        }
        .accessibilityHidden(true)
    }
}

private enum VoiceRecordCopy {
    static var language: AppLanguage { AppLocalization.language }

    static var title: String { value("语音记录", "語音記錄", "Voice record") }
    static var close: String { value("关闭语音记录", "關閉語音記錄", "Close voice record") }
    static var reset: String { value("复原", "復原", "Reset") }
    static var start: String { value("开始录音", "開始錄音", "Start recording") }
    static var stop: String { value("停止录音", "停止錄音", "Stop recording") }
    static var trySaying: String { value("试着说", "試著說", "Try saying") }
    static var recognizedText: String { value("实时识别", "即時辨識", "Live transcript") }
    static var sayWhatToRecord: String { value("说出要记录的内容", "說出要記錄的內容", "Say what you want to record") }
    static var preparing: String { value("正在准备", "正在準備", "Getting ready") }
    static var listening: String { value("正在听", "正在聽", "Listening") }
    static var converting: String { value("正在转换记录", "正在轉換記錄", "Converting record") }
    static var tapStop: String { value("说完后点停止", "說完後點停止", "Tap stop when finished") }
    static var pleaseWait: String { value("请稍等片刻", "請稍等片刻", "Please wait") }
    static var previewFirst: String { value("识别结果会先预览，不会直接保存", "辨識結果會先預覽，不會直接儲存", "You'll preview the result before saving") }
    static var convertedRecord: String { value("转换后的记录", "轉換後的記錄", "Converted record") }
    static var retry: String { value("重新录入", "重新錄入", "Try again") }
    static var confirmSave: String { value("确认保存", "確認儲存", "Confirm save") }
    static var editTranscript: String { value("修改识别文字", "修改辨識文字", "Edit transcript") }
    static var tapToEdit: String { value("点这里可修改识别文字", "點這裡可修改辨識文字", "Tap to edit the transcript") }
    static var editTranscriptHint: String { value("点到具体位置即可局部修改，完成后重新转换。", "點到具體位置即可局部修改，完成後重新轉換。", "Tap a specific position to make a local edit, then convert again.") }
    static var editingTranscript: String { value("正在修改识别文字", "正在修改辨識文字", "Editing transcript") }
    static var editThenConvert: String { value("只需修改听错的部分，不必重新说一遍", "只需修改聽錯的部分，不必重新說一遍", "Fix only the part that was misheard") }
    static var convertEditedText: String { value("重新转换", "重新轉換", "Convert again") }
    static var cancelEdit: String { value("取消修改", "取消修改", "Cancel") }
    static var editRecord: String { value("修改记录", "修改記錄", "Edit record") }
    static var editRecordHint: String { value("可以修改项目、数值和记录时间", "可以修改項目、數值和記錄時間", "Change the type, value, or record time") }
    static var keyboardInput: String { value("修改文字", "修改文字", "Edit text") }
    static var manualRecord: String { value("手动填写", "手動填寫", "Fill manually") }
    static var recordProject: String { value("记录项目", "記錄項目", "Record type") }
    static var chooseRecordProject: String { value("选择记录项目", "選擇記錄項目", "Choose record type") }
    static var chooseRecordProjectHint: String { value("识别错了也没关系，选择正确项目后继续修改。", "辨識錯了也沒關係，選擇正確項目後繼續修改。", "If recognition was wrong, choose the right type and continue editing.") }
    static var recordTime: String { value("记录时间", "記錄時間", "Record time") }
    static var value: String { value("数值", "數值", "Value") }
    static var genericActivity: String { value("日常活动", "日常活動", "Daily activity") }
    static var diaper: String { value("尿布", "尿布", "Diaper") }
    static var activity: String { value("活动", "活動", "Activity") }
    static var subjectiveState: String { value("Y 状态", "Y 狀態", "Y state") }
    static var editSubjectiveState: String { value("修改状态记录", "修改狀態記錄", "Edit state check-in") }
    static var babyState: String { value("宝宝状态", "寶寶狀態", "Baby state") }
    static var parentState: String { value("我的状态", "我的狀態", "My state") }
    static var editSolidRecord: String { value("修改辅食记录", "修改輔食記錄", "Edit solid-food record") }
    static var solidFood: String { value("食物", "食物", "Food") }
    static var unit: String { value("单位", "單位", "Unit") }
    static var savedContinue: String { value("已保存，可以继续录入下一条", "已儲存，可以繼續錄入下一條", "Saved. You can record another") }
    static var formula: String { value("奶粉瓶喂", "奶粉瓶餵", "Formula bottle") }
    static var expressed: String { value("母乳瓶喂", "母乳瓶餵", "Expressed milk") }
    static var nursing: String { value("母乳亲喂", "母乳親餵", "Nursing") }
    static var solids: String { value("宝宝辅食", "寶寶輔食", "Solid food") }
    static var wetDiaper: String { value("尿布 · 尿了", "尿布 · 尿了", "Wet diaper") }
    static var poopDiaper: String { value("尿布 · 拉了", "尿布 · 便便", "Dirty diaper") }
    static var sleep: String { value("睡眠", "睡眠", "Sleep") }
    static var activityCompleted: String { value("已完成", "已完成", "Completed") }
    static var noSpeech: String { value("没有听清内容，可以键盘输入或直接手动填写。", "沒有聽清內容，可以鍵盤輸入或直接手動填寫。", "Nothing was recognized. You can type it or fill the record manually.") }
    static var unsupportedSpeech: String { value("还没能自动判断记录项目，可以修改文字或直接手动填写。", "還未能自動判斷記錄項目，可以修改文字或直接手動填寫。", "The record type could not be determined. Edit the text or fill it manually.") }
    static var missingAmount: String { value("记录项目已识别，但数值没有听清。可以修改文字或手动补充。", "記錄項目已辨識，但數值沒有聽清。可以修改文字或手動補充。", "The record type was recognized, but the value was not. Edit the text or enter it manually.") }
    static var invalidValue: String { value("识别到的数值或时间需要确认，请修改后再保存。", "辨識到的數值或時間需要確認，請修改後再儲存。", "The recognized value or time needs confirmation. Edit it before saving.") }
    static var permissionDenied: String { value("需要麦克风和语音识别权限才能使用。可在系统设置中重新开启。", "需要咪高峰與語音辨識權限才能使用。可在系統設定中重新開啟。", "Microphone and speech-recognition access are required. You can enable them in Settings.") }
    static var openSettings: String { value("打开设置", "開啟設定", "Open Settings") }
    static var recognizerUnavailable: String { value("当前设备暂时无法启动语音识别，请稍后再试。", "目前裝置暫時無法啟動語音辨識，請稍後再試。", "Speech recognition is temporarily unavailable on this device.") }
    static var microphoneUnavailable: String { value("当前没有可用的麦克风输入，请检查系统麦克风或音频输入设置。", "目前沒有可用的咪高峰輸入，請檢查系統咪高峰或音訊輸入設定。", "No microphone input is available. Check the system microphone or audio input settings.") }
    static var simulatorMicrophoneUnavailable: String { value("模拟器的麦克风输入不可用，请在真机上测试语音记录。", "模擬器的咪高峰輸入不可用，請在真機上測試語音記錄。", "Simulator microphone input is unavailable. Test voice recording on a physical device.") }
    static func diaperDetail(_ kind: VoiceDiaperKind) -> String {
        let region = AppLocalization.locale.region?.identifier.uppercased()
        switch language {
        case .simplifiedChinese:
            return kind.detail
        case .traditionalChinese:
            let isHongKong = region == "HK" || region == "MO"
            switch kind {
            case .peeLow: return isHongKong ? "尿咗少少💧" : "尿了一點💧"
            case .peeMedium: return isHongKong ? "尿咗唔少💧💧" : "尿了不少💧💧"
            case .peeHigh: return isHongKong ? "尿咗好多💧💧💧" : "尿了很多💧💧💧"
            case .poopHard: return "硬結便"
            case .poopFormed: return "成型便"
            case .poopPaste: return "糊狀便"
            case .poopWatery: return "稀水便"
            case .poopMucus: return "黏液便"
            }
        case .english:
            let usesNappy = region.map { ["GB", "HK", "SG", "AU", "NZ", "IE"].contains($0) } ?? false
            let noun = usesNappy ? "nappy" : "diaper"
            switch kind {
            case .peeLow: return "Slightly wet \(noun) 💧"
            case .peeMedium: return "Wet \(noun) 💧💧"
            case .peeHigh: return "Very wet \(noun) 💧💧💧"
            case .poopHard: return "Hard stool"
            case .poopFormed: return "Formed stool"
            case .poopPaste: return "Pasty stool"
            case .poopWatery: return "Watery stool"
            case .poopMucus: return "Mucousy stool"
            }
        }
    }

    static var suggestions: [String] {
        let region = AppLocalization.locale.region?.identifier.uppercased()
        switch language {
        case .simplifiedChinese:
            if region == "SG" {
                return ["宝宝刚才小便了", "下午 1:20 睡到 3:05", "喝了 120 毫升配方奶", "今天体重 6.8 公斤"]
            }
            return ["刚刚尿布尿湿了", "下午 1:20 睡到 3:05", "喝了 120 毫升奶粉", "今天体重 6.8 公斤"]
        case .traditionalChinese:
            if region == "HK" || region == "MO" {
                return ["尿片啱啱濕咗", "下晝 1:20 瞓到 3:05", "飲咗 120 毫升奶粉", "今日體重 6.8 公斤"]
            }
            return ["剛剛尿尿了", "下午 1:20 睡到 3:05", "喝了 120 毫升配方奶", "今天體重 6.8 公斤"]
        case .english:
            if region == "GB" || region == "HK" || region == "SG" {
                return ["The nappy was quite wet", "Slept from 1:20 PM to 3:05 PM", "Took 120 ml of formula", "Weight is 6.8 kg today"]
            }
            return ["The diaper was pretty wet", "Slept from 1:20 PM to 3:05 PM", "Drank 4 fl oz of formula", "Weight is 15 pounds today"]
        }
    }

    static func savedCount(_ count: Int) -> String {
        switch language {
        case .simplifiedChinese: return "本次已保存 \(count) 条"
        case .traditionalChinese: return "本次已儲存 \(count) 條"
        case .english: return "\(count) saved this session"
        }
    }

    private static func value(_ simplified: String, _ traditional: String, _ english: String) -> String {
        switch language {
        case .simplifiedChinese: return simplified
        case .traditionalChinese: return traditional
        case .english: return english
        }
    }
}
