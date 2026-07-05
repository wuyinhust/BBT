import SwiftUI

struct FeedingEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var feedingStore: FeedingStore
    let session: FeedingSession

    @State private var entries: [FeedingEntry]
    @State private var note: String
    @State private var mood: BabyMood
    @State private var recordedAt: Date
    @State private var imageData: Data?

    init(session: FeedingSession) {
        self.session = session
        _entries = State(initialValue: session.entries)
        _note = State(initialValue: session.notes)
        _mood = State(initialValue: session.babyMood)
        _recordedAt = State(initialValue: session.createdAt)
        _imageData = State(initialValue: session.imageData)
    }

    var body: some View {
        NavigationStack {
            recordEditSheetContent(
                title: "修改喂养",
                subtitle: "调整时间和明细",
                icon: "fork.knife.circle.fill",
                accent: DesignToken.primary
            ) {
                VStack(spacing: 16) {
                    DatePicker("时间", selection: $recordedAt, in: ...Date(), displayedComponents: [.hourAndMinute])
                        .font(BBBFont.font(size: 17, weight: .semibold))
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))

                    moodPicker

                    VStack(spacing: 12) {
                        ForEach($entries) { $entry in
                            FeedingEntryEditRow(entry: $entry)
                        }
                    }

                    recordEditSaveButton(title: "保存修改", color: DesignToken.primary) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("修改喂养")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("宝宝反应")
                .font(BBBFont.font(size: 17, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)

            HStack(spacing: 10) {
                ForEach(BabyMood.allCases, id: \.self) { item in
                    Button {
                        mood = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 26))
                            .frame(width: 50, height: 42)
                            .background(Capsule().fill(mood == item ? DesignToken.primary.opacity(0.18) : DesignToken.iconSoftBG))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
    }

    private func save() {
        guard canSave else { return }
        let base = FeedingSession(
            id: session.id,
            entries: entries,
            notes: session.notes,
            imageData: imageData,
            babyMood: mood,
            createdAt: recordedAt,
            startAt: session.startAt,
            endAt: session.endAt,
            timeSpanSource: session.timeSpanSource
        )
        let resolvedSpan = base.resolvedTimeSpan(ageMonths: profileStore.currentProfile.ageMonths)
        let updated = FeedingSession(
            id: session.id,
            entries: entries,
            notes: session.notes,
            imageData: imageData,
            babyMood: mood,
            createdAt: recordedAt,
            startAt: resolvedSpan.endAt > resolvedSpan.startAt ? resolvedSpan.startAt : nil,
            endAt: resolvedSpan.endAt > resolvedSpan.startAt ? resolvedSpan.endAt : nil,
            timeSpanSource: resolvedSpan.source
        )
        feedingStore.updateSession(updated)
        dismiss()
    }

    private var canSave: Bool {
        !entries.isEmpty && recordedAt <= Date()
    }
}

private struct FeedingEntryEditRow: View {
    @Binding var entry: FeedingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(BBBFont.font(size: 17, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)

            switch entry.type {
            case .breast:
                Picker("方式", selection: breastModeBinding) {
                    ForEach(BreastFeedingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("侧边", selection: breastSideBinding) {
                    ForEach(BreastSide.allCases) { side in
                        Text(side.displayName).tag(side)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: breastDurationBinding, in: 1...120, step: 1) {
                    valueLine("时长", "\(entry.breastDuration ?? 1) 分钟")
                }

            case .bottle:
                Picker("奶类型", selection: milkTypeBinding) {
                    ForEach(MilkType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: bottleAmountBinding, in: 0...300, step: 5) {
                    valueLine("奶量", "\(entry.bottleAmount ?? 0)ml")
                }

                Stepper(value: bottleDurationBinding, in: 0...120, step: 1) {
                    valueLine("时长", bottleDurationText)
                }

            case .solid:
                Picker("辅食", selection: solidFoodBinding) {
                    ForEach(SolidFood.allCases) { food in
                        Text("\(food.emoji) \(food.displayName)").tag(food)
                    }
                }

                Picker("单位", selection: solidUnitBinding) {
                    ForEach(SolidUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: solidAmountBinding, in: 0...500, step: 5) {
                    valueLine("分量", "\(Int(entry.solidAmount ?? 0))\(entry.solidUnit?.displayName ?? "g")")
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
    }

    private var title: String {
        switch entry.type {
        case .breast: return "母乳（亲喂）"
        case .bottle:
            if entry.milkType == .expressed { return "母乳（瓶喂）" }
            return "奶粉（瓶喂）"
        case .solid: return "辅食"
        }
    }

    private var icon: String {
        switch entry.type {
        case .breast: return "heart.fill"
        case .bottle: return "babybottle.fill"
        case .solid: return "fork.knife"
        }
    }

    private var bottleDurationText: String {
        guard let duration = entry.bottleDuration, duration > 0 else { return "未记录" }
        return "\(duration) 分钟"
    }

    private func valueLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .foregroundStyle(DesignToken.textPrimary)
        }
    }

    private var breastModeBinding: Binding<BreastFeedingMode> {
        Binding {
            entry.breastMode ?? .pumping
        } set: {
            entry.breastMode = $0
        }
    }

    private var breastSideBinding: Binding<BreastSide> {
        Binding {
            entry.breastSide ?? .left
        } set: {
            entry.breastSide = $0
        }
    }

    private var breastDurationBinding: Binding<Int> {
        Binding {
            entry.breastDuration ?? 1
        } set: {
            entry.breastDuration = $0
        }
    }

    private var milkTypeBinding: Binding<MilkType> {
        Binding {
            entry.milkType ?? .formula
        } set: {
            entry.milkType = $0
        }
    }

    private var bottleAmountBinding: Binding<Int> {
        Binding {
            entry.bottleAmount ?? 0
        } set: {
            entry.bottleAmount = $0
        }
    }

    private var bottleDurationBinding: Binding<Int> {
        Binding {
            entry.bottleDuration ?? 0
        } set: {
            entry.bottleDuration = $0 == 0 ? nil : $0
        }
    }

    private var solidFoodBinding: Binding<SolidFood> {
        Binding {
            entry.solidFood ?? .rice
        } set: {
            entry.solidFood = $0
            entry.solidUnit = $0.suggestedUnit
        }
    }

    private var solidUnitBinding: Binding<SolidUnit> {
        Binding {
            entry.solidUnit ?? .g
        } set: {
            entry.solidUnit = $0
        }
    }

    private var solidAmountBinding: Binding<Double> {
        Binding {
            entry.solidAmount ?? 0
        } set: {
            entry.solidAmount = $0
        }
    }
}

struct CareRecordEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var activityStore: ActivityStore
    let record: CareRecord

    @State private var diaperType: String
    @State private var note: String
    @State private var recordedAt: Date
    @State private var sleepEndAt: Date

    private let diaperTypes = DiaperRecordType.allCases.map(\.rawValue)

    init(record: CareRecord) {
        self.record = record
        _diaperType = State(initialValue: DiaperRecordType.normalizedTitle(record.title))
        _note = State(initialValue: record.note)
        _recordedAt = State(initialValue: record.recordedAt)
        _sleepEndAt = State(initialValue: Self.initialSleepEndAt(from: record))
    }

    var body: some View {
        NavigationStack {
            switch record.kind {
            case .diaper:
                diaperContent
            case .activity:
                activityContent
            case .sleep:
                sleepContent
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var activityContent: some View {
        recordEditSheetContent(
            title: "修改活动",
            subtitle: "调整活动时间",
            icon: "sparkles",
            accent: DesignToken.easyActivity
        ) {
            VStack(spacing: 16) {
                DatePicker("时间", selection: $recordedAt, in: ...Date(), displayedComponents: [.hourAndMinute])
                    .font(BBBFont.font(size: 17, weight: .semibold))

                recordEditSaveButton(title: "保存修改", color: DesignToken.easyActivity) {
                    activityStore.updateActivityRecord(record, recordedAt: recordedAt)
                    dismiss()
                }
            }
        }
        .navigationTitle("修改活动")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
    }

    private var diaperContent: some View {
        recordEditSheetContent(
            title: "修改尿布",
            subtitle: "调整尿布状态和时间",
            icon: "drop.fill",
            accent: DesignToken.activityDiaper
        ) {
            VStack(spacing: 16) {
                Picker("尿布状态", selection: $diaperType) {
                    ForEach(diaperTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                DatePicker("时间", selection: $recordedAt, in: ...Date(), displayedComponents: [.hourAndMinute])
                    .font(BBBFont.font(size: 17, weight: .semibold))

                recordEditSaveButton(title: "保存修改", color: DesignToken.activityDiaper) {
                    guard canSaveDiaper else { return }
                    activityStore.updateDiaperRecord(record, type: diaperType, detail: record.detail, note: record.note, recordedAt: recordedAt)
                    dismiss()
                }
                .disabled(!canSaveDiaper)
            }
        }
        .navigationTitle("修改尿布")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
    }

    private var sleepContent: some View {
        recordEditSheetContent(
            title: "修改睡眠",
            subtitle: "调整睡眠时长和时间",
            icon: "moon.fill",
            accent: DesignToken.easySleep
        ) {
            VStack(spacing: 16) {
                DatePicker("入睡", selection: $recordedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    .font(BBBFont.font(size: 17, weight: .semibold))

                DatePicker("醒来", selection: $sleepEndAt, in: recordedAt...Date(), displayedComponents: [.date, .hourAndMinute])
                    .font(BBBFont.font(size: 17, weight: .semibold))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("睡眠时长", systemImage: "timer")
                            .font(BBBFont.font(size: 17, weight: .bold))
                        Spacer()
                        Text(SleepRecordFormatter.durationText(minutes: sleepDurationMinutes))
                            .font(BBBFont.font(size: 17, weight: .heavy))
                            .foregroundStyle(canSaveSleep ? DesignToken.easySleep : Color.red.opacity(0.8))
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))

                Button {
                    guard canSaveSleep else { return }
                    activityStore.updateSleepRecord(record, startTime: recordedAt, endTime: sleepEndAt, note: record.note)
                    dismiss()
                } label: {
                    Label("保存修改", systemImage: "checkmark.circle.fill")
                        .font(BBBFont.font(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(canSaveSleep ? DesignToken.easySleep : Color.gray.opacity(0.36)))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!canSaveSleep)
            }
        }
        .navigationTitle("修改睡眠")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: recordedAt) { _, newValue in
            if sleepEndAt <= newValue {
                sleepEndAt = min(Date(), newValue.addingTimeInterval(30 * 60))
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
    }

    private func notesField(_ placeholder: String) -> some View {
        TextField(placeholder, text: $note, axis: .vertical)
            .lineLimit(3, reservesSpace: true)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
    }

    private var sleepDurationMinutes: Int {
        max(Int(sleepEndAt.timeIntervalSince(recordedAt) / 60), 0)
    }

    private var canSaveSleep: Bool {
        sleepDurationMinutes > 0
    }

    private var canSaveDiaper: Bool {
        recordedAt <= Date()
    }

    private static func initialSleepEndAt(from record: CareRecord) -> Date {
        let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) ?? 30
        return SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
    }
}

struct GrowthMetricEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    let record: GrowthMetricRecord

    @State private var value: Double
    @State private var note: String
    @State private var recordedAt: Date

    init(record: GrowthMetricRecord) {
        self.record = record
        _value = State(initialValue: record.value)
        _note = State(initialValue: record.note)
        _recordedAt = State(initialValue: record.recordedAt)
    }

    var body: some View {
        NavigationStack {
            recordEditSheetContent(
                title: "修改\(record.kind.title)",
                subtitle: "调整数值、时间和备注",
                icon: record.kind.icon,
                accent: record.kind.accent
            ) {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(String(format: "%.1f", value))
                                .font(BBBFont.font(size: 42, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary)
                                .monospacedDigit()
                            Text(record.kind.unit)
                                .font(BBBFont.font(size: 22, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary)
                        }

                        Slider(value: $value, in: valueRange, step: 0.1)
                            .tint(record.kind.accent)

                        Stepper("调整\(record.kind.title)", value: $value, in: valueRange, step: 0.1)
                            .labelsHidden()
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))

                    DatePicker("时间", selection: $recordedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .font(BBBFont.font(size: 17, weight: .semibold))
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))

                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))

                    recordEditSaveButton(title: "保存修改", color: record.kind.accent) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("修改\(record.kind.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var valueRange: ClosedRange<Double> {
        record.kind == .weight ? 0.5...40 : 20...130
    }

    private var canSave: Bool {
        value > 0 && recordedAt <= Date()
    }

    private func save() {
        guard canSave else { return }
        growthMetricStore.updateRecord(record, value: value, note: note, recordedAt: recordedAt)
        dismiss()
    }
}

private func recordEditSheetContent<Content: View>(
    title: String,
    subtitle: String,
    icon: String,
    accent: Color,
    @ViewBuilder content: () -> Content
) -> some View {
    ZStack {
        Color(hex: "#F8F7FB").ignoresSafeArea()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(accent))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(BBBFont.font(size: 22, weight: .bold))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(subtitle)
                            .font(BBBFont.font(size: 13, weight: .medium))
                            .foregroundStyle(DesignToken.textSecondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))

                content()
            }
            .padding(18)
        }
    }
}

private func recordEditSaveButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(BBBFont.font(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(color))
    }
    .buttonStyle(ScaleButtonStyle())
}
