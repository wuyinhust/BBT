import SwiftUI

struct GrowthMetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @Environment(BabyProfileStore.self) private var profileStore

    let kind: GrowthMetricKind

    @State private var pendingDeletion: GrowthMetricRecord?
    @AppStorage(
        GrowthStandardPreference.storageKey,
        store: GrowthStandardPreference.defaults
    ) private var growthStandardPreferenceRaw = GrowthStandardPreference.automatic.rawValue

    init(kind: GrowthMetricKind) {
        self.kind = kind
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HomeSoftBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignToken.contentSpacing) {
                        growthCurveCard
                        recentRecordsCard
                    }
                    .padding(.horizontal, DesignToken.compactHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("\(kind.title)曲线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppPageCloseButton {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                recordDock
            }
            .confirmationDialog(
                "删除这条\(kind.title)记录？",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除记录", role: .destructive) {
                    deletePendingRecord()
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let pendingDeletion {
                    Text("\(dateText(pendingDeletion.recordedAt)) · \(displayValue(pendingDeletion.value))。删除后会从生长曲线和成长记录中移除。")
                }
            }
        }
    }

    private var growthCurveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(growthStandard.shortTitle) 生长曲线")
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(curveSubtitle)
                        .font(BBBFont.font(size: 10.5, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer(minLength: 8)

                if let assessment {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(assessment.percentileText)
                            .font(BBBFont.font(size: 18, weight: .heavy))
                            .foregroundStyle(kind.accent)
                        Text("当前百分位")
                            .font(BBBFont.font(size: 9, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                    }
                }
            }

            WHOGrowthCurveView(
                kind: kind,
                gender: profileStore.currentProfile.gender,
                birthDate: profileStore.currentProfile.birthDate,
                records: records,
                previewValue: nil,
                previewDate: nil,
                accent: kind.accent,
                standard: growthStandard
            )
            .frame(height: 238)

            HStack(spacing: 8) {
                curveLegend(color: kind.accent, title: "宝宝记录")
                curveLegend(color: DesignToken.textSecondary.opacity(0.42), title: "\(growthStandard.shortTitle) P3–P97")
                Spacer()
            }

            Text(assessmentGuidance)
                .font(BBBFont.font(size: 10, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .growthRecorderSurface(accent: kind.accent)
    }

    private func curveLegend(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 14, height: 4)
            Text(title.localized)
        }
        .font(BBBFont.font(size: 9.5, weight: .semibold))
        .foregroundStyle(DesignToken.textSecondary)
    }

    @ViewBuilder
    private var recentRecordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(kind.title)记录")
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Text("共 \(records.count) 条")
                    .font(BBBFont.font(size: 10.5, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            if records.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: kind.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(kind.accent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(kind.accent.opacity(0.10)))
                    Text("还没有\(kind.title)记录")
                        .font(BBBFont.font(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                ForEach(records) { record in
                    HStack(spacing: 8) {
                        NavigationLink {
                            GrowthMetricEntryView(kind: kind, existingRecord: record)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dateText(record.recordedAt))
                                        .font(BBBFont.font(size: 11, weight: .bold))
                                        .foregroundStyle(DesignToken.textPrimary)
                                    if !record.note.isEmpty {
                                        Text(record.note.localized)
                                            .font(BBBFont.font(size: 9.5, weight: .semibold))
                                            .foregroundStyle(DesignToken.textSecondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text(displayValue(record.value))
                                    .font(BBBFont.font(size: 13, weight: .heavy))
                                    .foregroundStyle(DesignToken.textPrimary)

                                if let recordAssessment = assessment(for: record.value, at: record.recordedAt) {
                                    Text(recordAssessment.percentileText)
                                        .font(BBBFont.font(size: 10, weight: .bold))
                                        .foregroundStyle(kind.accent)
                                        .frame(width: 38, alignment: .trailing)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(DesignToken.textSecondary.opacity(0.56))
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            pendingDeletion = record
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DesignToken.error.opacity(0.78))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除\(dateText(record.recordedAt))的\(kind.title)记录")
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingDeletion = record
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }

                    if record.id != records.last?.id {
                        Divider().opacity(0.34)
                    }
                }
            }
        }
        .padding(16)
        .growthRecorderSurface(accent: kind.accent)
    }

    private var recordDock: some View {
        NavigationLink {
            GrowthMetricEntryView(kind: kind)
        } label: {
            Label("记录\(kind.title)", systemImage: "plus")
                .font(BBBFont.font(size: 15, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule(style: .continuous).fill(kind.accent))
                .shadow(color: kind.accent.opacity(0.20), radius: 14, y: 7)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var profile: BabyProfileData {
        profileStore.currentProfile
    }

    private var records: [GrowthMetricRecord] {
        growthMetricStore.records(kind: kind)
    }

    private var growthStandard: GrowthReferenceStandard {
        GrowthStandardPreference(rawValue: growthStandardPreferenceRaw)?.resolvedStandard
            ?? GrowthStandardPreference.defaultStandard
    }

    private var assessment: WHOGrowthAssessment? {
        guard let latest = records.first else { return nil }
        return assessment(for: latest.value, at: latest.recordedAt)
    }

    private func assessment(for value: Double, at date: Date) -> WHOGrowthAssessment? {
        let days = max(date.timeIntervalSince(profile.birthDate) / 86_400, 0)
        return GrowthReference.assessment(
            standard: growthStandard,
            kind: kind,
            gender: profile.gender,
            ageDays: days,
            value: value
        )
    }

    private var curveSubtitle: String {
        let sex = profile.gender == .boy ? "男童" : "女童"
        let metric = kind == .weight ? "体重年龄别" : "身长/身高年龄别"
        return "\(metric) · \(sex) · \(growthStandard.supportedAgeText)"
    }

    private var assessmentGuidance: String {
        guard let assessment else {
            return "\(growthStandard.title)支持 \(growthStandard.supportedAgeText)；超出范围时仅保留个人趋势。"
        }
        return "当前约处于 \(growthStandard.shortTitle) \(assessment.percentileText)。百分位用于观察连续趋势，不替代儿保或医生评估。"
    }

    private func format(_ number: Double) -> String {
        String(format: "%.1f", number)
    }

    private func displayValue(_ canonicalValue: Double) -> String {
        switch kind {
        case .weight: return AppMeasurementFormat.weight(canonicalValue)
        case .height: return AppMeasurementFormat.height(canonicalValue)
        }
    }

    private func dateText(_ date: Date) -> String {
        AppDateTimeFormat.dateTime(date)
    }

    private func deletePendingRecord() {
        guard let pendingDeletion else { return }
        growthMetricStore.deleteRecord(pendingDeletion)
        self.pendingDeletion = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct GrowthMetricEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @Environment(BabyProfileStore.self) private var profileStore

    let kind: GrowthMetricKind
    let existingRecord: GrowthMetricRecord?

    @State private var valueText = ""
    @State private var secondaryValueText = ""
    @State private var rulerValue: Double
    @State private var note = ""
    @State private var recordedAt = Date()
    @State private var didLoad = false
    @AppStorage(
        GrowthStandardPreference.storageKey,
        store: GrowthStandardPreference.defaults
    ) private var growthStandardPreferenceRaw = GrowthStandardPreference.automatic.rawValue

    init(kind: GrowthMetricKind, existingRecord: GrowthMetricRecord? = nil) {
        self.kind = kind
        self.existingRecord = existingRecord
        _rulerValue = State(initialValue: kind == .weight ? 7.5 : 68)
    }

    var body: some View {
        ZStack {
            HomeSoftBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DesignToken.contentSpacing) {
                    valueCard
                    measurementDetails
                }
                .padding(.horizontal, DesignToken.compactHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(
            AppLocalization.format(
                existingRecord == nil ? "记录%@" : "编辑%@",
                kind.title
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveDock
        }
        .onAppear(perform: loadInitialValue)
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("本次测量")
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(comparisonText)
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                if let assessment {
                    Text(assessment.percentileText)
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(kind.accent)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Capsule().fill(kind.accent.opacity(0.10)))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("—", text: $valueText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignToken.textPrimary)
                    .monospacedDigit()
                    .frame(maxWidth: 190)
                    .accessibilityLabel("输入数值")
                    .onChange(of: valueText) { _, newValue in
                        if isImperialWeight {
                            syncRulerFromImperialWeightFields()
                            return
                        }
                        guard let number = number(from: newValue), valueRange.contains(number) else { return }
                        rulerValue = number
                    }

                Text(displayUnit)
                    .font(BBBFont.font(size: 16, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)

                if isImperialWeight {
                    TextField("0", text: $secondaryValueText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignToken.textPrimary)
                        .monospacedDigit()
                        .frame(maxWidth: 88)
                        .onChange(of: secondaryValueText) { _, _ in
                            syncRulerFromImperialWeightFields()
                        }

                    Text(AppMeasurementFormat.weightSecondaryUnit)
                        .font(BBBFont.font(size: 16, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                valueStepButton(systemName: "minus", delta: -0.1)
                valueStepButton(systemName: "plus", delta: 0.1)
            }

            GrowthMetricRuler(
                value: rulerBinding,
                range: valueRange,
                step: 0.1,
                accent: kind.accent
            )

            Text(rulerHint)
                .font(BBBFont.font(size: 10, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .padding(16)
        .growthRecorderSurface(accent: kind.accent)
    }

    private var measurementDetails: some View {
        VStack(spacing: 0) {
            DatePicker(
                "测量时间",
                selection: $recordedAt,
                in: safeBirthDate...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(BBBFont.font(size: 13, weight: .bold))
            .padding(.vertical, 4)

            Divider().opacity(0.40).padding(.vertical, 12)

            TextField("备注（可选）", text: $note, axis: .vertical)
                .font(BBBFont.font(size: 12, weight: .semibold))
                .lineLimit(3, reservesSpace: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DesignToken.surfaceSoft.opacity(0.80)))
        }
        .padding(16)
        .growthRecorderSurface(accent: kind.accent)
    }

    private func valueStepButton(systemName: String, delta: Double) -> some View {
        Button {
            setValue(rulerValue + delta)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(kind.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(kind.accent.opacity(0.10)))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var saveDock: some View {
        Button(action: save) {
            Text(
                existingRecord == nil
                    ? AppLocalization.format("保存%@记录", kind.title)
                    : "保存修改".localized
            )
                .font(BBBFont.font(size: 15, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule(style: .continuous).fill(kind.accent))
                .shadow(color: kind.accent.opacity(0.20), radius: 14, y: 7)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.45)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var profile: BabyProfileData {
        profileStore.currentProfile
    }

    private var growthStandard: GrowthReferenceStandard {
        GrowthStandardPreference(rawValue: growthStandardPreferenceRaw)?.resolvedStandard
            ?? GrowthStandardPreference.defaultStandard
    }

    private var valueRange: ClosedRange<Double> {
        let lower = displayValue(fromCanonical: kind.validRange.lowerBound)
        let upper = displayValue(fromCanonical: kind.validRange.upperBound)
        return lower...upper
    }

    private var enteredValue: Double? {
        guard let value = displayValueFromFields, valueRange.contains(value) else { return nil }
        return canonicalValue(fromDisplay: value)
    }

    private var assessment: WHOGrowthAssessment? {
        guard let enteredValue else { return nil }
        let ageDays = max(recordedAt.timeIntervalSince(profile.birthDate) / 86_400, 0)
        return GrowthReference.assessment(
            standard: growthStandard,
            kind: kind,
            gender: profile.gender,
            ageDays: ageDays,
            value: enteredValue
        )
    }

    private var comparisonText: String {
        guard let enteredValue else { return "输入数字，或滑动尺子快速录入".localized }
        guard let latest = growthMetricStore.latest(kind: kind), latest.id != existingRecord?.id else {
            return existingRecord == nil ? "首次记录".localized : "正在修改这条记录".localized
        }
        let delta = enteredValue - latest.value
        if abs(delta) < 0.05 { return "与上次记录相同".localized }
        let displayDelta: String
        switch kind {
        case .weight: displayDelta = AppMeasurementFormat.weight(abs(delta))
        case .height: displayDelta = AppMeasurementFormat.height(abs(delta))
        }
        return AppLocalization.format("较上次 %@%@", delta > 0 ? "+" : "-", displayDelta)
    }

    private var rulerHint: String {
        valueText.isEmpty
            ? "尺子停在 \(growthStandard.shortTitle) P50 参考起点；滑动后才会录入".localized
            : "拖动尺子快速调整，也可以直接点击上方数字输入".localized
    }

    private var rulerBinding: Binding<Double> {
        Binding(
            get: { rulerValue },
            set: { setValue($0) }
        )
    }

    private var canSave: Bool {
        enteredValue != nil && recordedAt >= safeBirthDate && recordedAt <= Date()
    }

    private var safeBirthDate: Date {
        min(profile.birthDate, Date())
    }

    private func loadInitialValue() {
        guard !didLoad else { return }
        didLoad = true

        if let existingRecord {
            setCanonicalValue(existingRecord.value)
            note = existingRecord.note
            recordedAt = existingRecord.recordedAt
            return
        }

        if let latest = growthMetricStore.latest(kind: kind)?.value
            ?? (kind == .weight ? profile.weightKg : profile.heightCm) {
            setCanonicalValue(latest)
            return
        }

        let ageDays = max(Date().timeIntervalSince(profile.birthDate) / 86_400, 0)
        let reference = GrowthReference.value(
            standard: growthStandard,
            kind: kind,
            gender: profile.gender,
            ageDays: ageDays,
            zScore: 0
        ) ?? rulerValue
        rulerValue = clamped(displayValue(fromCanonical: reference))
        valueText = ""
        secondaryValueText = ""
    }

    private func setValue(_ newValue: Double) {
        let adjusted = clamped(newValue)
        rulerValue = adjusted
        if isImperialWeight {
            let pounds = max(Int(floor(adjusted)), 0)
            var ounces = max((adjusted - Double(pounds)) * 16, 0)
            ounces = (ounces * 10).rounded() / 10
            valueText = String(pounds)
            secondaryValueText = AppMeasurementFormat.inputNumber(ounces, maximumFractionDigits: 1)
        } else {
            valueText = AppMeasurementFormat.inputNumber(adjusted, maximumFractionDigits: 1)
        }
    }

    private func setCanonicalValue(_ canonicalValue: Double) {
        setValue(displayValue(fromCanonical: canonicalValue))
    }

    private func clamped(_ value: Double) -> Double {
        min(max((value * 10).rounded() / 10, valueRange.lowerBound), valueRange.upperBound)
    }

    private func number(from text: String) -> Double? {
        AppMeasurementFormat.parseNumber(text)
    }

    private func save() {
        guard let enteredValue, canSave else { return }
        if let existingRecord {
            growthMetricStore.updateRecord(existingRecord, value: enteredValue, note: note, recordedAt: recordedAt)
        } else {
            growthMetricStore.saveRecord(kind: kind, value: enteredValue, note: note, recordedAt: recordedAt)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func format(_ number: Double) -> String {
        String(format: "%.1f", number)
    }

    private var isImperialWeight: Bool {
        kind == .weight && AppMeasurementFormat.currentSystem == .imperial
    }

    private var displayUnit: String {
        switch kind {
        case .weight: return AppMeasurementFormat.weightPrimaryUnit
        case .height: return AppMeasurementFormat.heightUnit
        }
    }

    private var displayValueFromFields: Double? {
        guard let primary = number(from: valueText), primary >= 0 else { return nil }
        guard isImperialWeight else { return primary }
        let ounces = number(from: secondaryValueText) ?? 0
        guard ounces >= 0, ounces < 16 else { return nil }
        return primary + ounces / 16
    }

    private func displayValue(fromCanonical canonicalValue: Double) -> Double {
        switch kind {
        case .height:
            return AppMeasurementFormat.heightValue(fromCentimeters: canonicalValue)
        case .weight:
            guard AppMeasurementFormat.currentSystem == .imperial else { return canonicalValue }
            let parts = AppMeasurementFormat.poundsAndOunces(fromKilograms: canonicalValue)
            return Double(parts.pounds) + parts.ounces / 16
        }
    }

    private func canonicalValue(fromDisplay displayValue: Double) -> Double {
        switch kind {
        case .height:
            return AppMeasurementFormat.centimeters(fromHeightValue: displayValue)
        case .weight:
            guard AppMeasurementFormat.currentSystem == .imperial else { return displayValue }
            let pounds = floor(displayValue)
            let ounces = (displayValue - pounds) * 16
            return AppMeasurementFormat.kilograms(pounds: pounds, ounces: ounces)
        }
    }

    private func syncRulerFromImperialWeightFields() {
        guard isImperialWeight,
              let value = displayValueFromFields,
              valueRange.contains(value) else { return }
        rulerValue = value
    }
}

private struct GrowthMetricRuler: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let accent: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                GeometryReader { proxy in
                    Canvas { context, size in
                        let count = 40
                        for index in 0...count {
                            let x = CGFloat(index) / CGFloat(count) * size.width
                            let isMajor = index.isMultiple(of: 5)
                            let height: CGFloat = isMajor ? 16 : 9
                            var tick = Path()
                            tick.move(to: CGPoint(x: x, y: size.height - height))
                            tick.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(
                                tick,
                                with: .color(isMajor ? accent.opacity(0.40) : DesignToken.textSecondary.opacity(0.20)),
                                lineWidth: isMajor ? 1.2 : 0.8
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                }

                Slider(value: $value, in: range, step: step)
                    .tint(accent)
            }
            .frame(height: 42)

            HStack {
                Text(String(format: "%.1f", range.lowerBound))
                Spacer()
                Text(String(format: "%.1f", value))
                    .foregroundStyle(accent)
                Spacer()
                Text(String(format: "%.1f", range.upperBound))
            }
            .font(BBBFont.font(size: 9.5, weight: .semibold))
            .foregroundStyle(DesignToken.textSecondary.opacity(0.78))
            .monospacedDigit()
        }
    }
}

private struct WHOGrowthCurveView: View {
    let kind: GrowthMetricKind
    let gender: BabyGender
    let birthDate: Date
    let records: [GrowthMetricRecord]
    let previewValue: Double?
    let previewDate: Date?
    let accent: Color
    let standard: GrowthReferenceStandard

    @State private var selectedPoint: WHOGrowthPlotPoint?

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { proxy in
                let plot = plotRect(in: proxy.size)

                Canvas { context, _ in
                    drawGrid(context: context, plot: plot)
                    drawReferenceCurves(context: context, plot: plot)
                    drawRecords(context: context, plot: plot)
                    drawLabels(context: context, plot: plot)
                }
                .contentShape(Rectangle())
                .gesture(inspectGesture(plot: plot))
                .overlay(alignment: .topLeading) {
                    if let selectedPoint {
                        pointCallout(selectedPoint)
                            .padding(.leading, 38)
                            .padding(.top, 4)
                    }
                }
            }

            HStack {
                Text("0")
                Spacer()
                Text("\(Int(maxMonths / 2))月")
                Spacer()
                Text("\(Int(maxMonths))月")
            }
            .font(BBBFont.font(size: 9, weight: .semibold))
            .foregroundStyle(DesignToken.textSecondary.opacity(0.74))
            .padding(.leading, 34)
            .padding(.trailing, 8)
        }
    }

    private var plottedPoints: [WHOGrowthPlotPoint] {
        let saved = records.compactMap { record -> WHOGrowthPlotPoint? in
            let months = record.recordedAt.timeIntervalSince(birthDate) / (86_400 * 30.4375)
            guard months >= 0, months <= maximumSupportedMonths else { return nil }
            return WHOGrowthPlotPoint(id: record.id, months: months, value: record.value, date: record.recordedAt, isPreview: false)
        }
        guard let previewValue, let previewDate else {
            return saved.sorted { $0.months < $1.months }
        }
        let previewMonths = previewDate.timeIntervalSince(birthDate) / (86_400 * 30.4375)
        let preview = WHOGrowthPlotPoint(id: UUID(), months: max(previewMonths, 0), value: previewValue, date: previewDate, isPreview: true)
        return (saved + (previewMonths <= maximumSupportedMonths ? [preview] : [])).sorted { $0.months < $1.months }
    }

    private var currentAgeMonths: Double {
        let referenceDate = previewDate ?? records.first?.recordedAt ?? Date()
        return max(referenceDate.timeIntervalSince(birthDate) / (86_400 * 30.4375), 0)
    }

    private var maxMonths: Double {
        let supported = maximumSupportedMonths
        switch min(currentAgeMonths, supported) {
        case ...12: return min(12, supported)
        case ...24: return min(24, supported)
        case ...36: return min(36, supported)
        case ...60: return min(60, supported)
        default: return supported
        }
    }

    private var maximumSupportedMonths: Double {
        GrowthReference.supportedAgeDays(for: standard).upperBound / (86_400 * 30.4375)
    }

    private var yBounds: ClosedRange<Double> {
        let ages = stride(from: 0.0, through: maxMonths, by: 1).map { $0 * 30.4375 }
        let lower = ages.compactMap {
            GrowthReference.value(standard: standard, kind: kind, gender: gender, ageDays: $0, zScore: -1.880793608)
        }.min() ?? 0
        let upper = ages.compactMap {
            GrowthReference.value(standard: standard, kind: kind, gender: gender, ageDays: $0, zScore: 1.880793608)
        }.max() ?? 1
        let recordValues = plottedPoints.map(\.value)
        let minValue = min(lower, recordValues.min() ?? lower)
        let maxValue = max(upper, recordValues.max() ?? upper)
        let padding = max((maxValue - minValue) * 0.10, kind == .weight ? 0.5 : 2)
        return (minValue - padding)...(maxValue + padding)
    }

    private func plotRect(in size: CGSize) -> CGRect {
        CGRect(x: 34, y: 10, width: max(size.width - 42, 1), height: max(size.height - 16, 1))
    }

    private func drawGrid(context: GraphicsContext, plot: CGRect) {
        for index in 0...4 {
            let fraction = CGFloat(index) / 4
            let y = plot.maxY - fraction * plot.height
            var path = Path()
            path.move(to: CGPoint(x: plot.minX, y: y))
            path.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(path, with: .color(DesignToken.borderSubtle.opacity(0.52)), lineWidth: 0.7)
        }
        for index in 0...6 {
            let x = plot.minX + CGFloat(index) / 6 * plot.width
            var path = Path()
            path.move(to: CGPoint(x: x, y: plot.minY))
            path.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(path, with: .color(DesignToken.borderSubtle.opacity(0.34)), lineWidth: 0.6)
        }
    }

    private func drawReferenceCurves(context: GraphicsContext, plot: CGRect) {
        for curve in GrowthReference.curvePercentiles {
            var path = Path()
            var didMove = false
            for month in stride(from: 0.0, through: maxMonths, by: 0.5) {
                guard let value = GrowthReference.value(
                    standard: standard,
                    kind: kind,
                    gender: gender,
                    ageDays: month * 30.4375,
                    zScore: curve.z
                ) else { continue }
                let point = chartPoint(months: month, value: value, plot: plot)
                if didMove { path.addLine(to: point) } else { path.move(to: point); didMove = true }
            }
            let isMedian = curve.label == "P50"
            context.stroke(
                path,
                with: .color(accent.opacity(isMedian ? 0.36 : 0.20)),
                style: StrokeStyle(lineWidth: isMedian ? 1.5 : 0.9, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawRecords(context: GraphicsContext, plot: CGRect) {
        let saved = plottedPoints.filter { !$0.isPreview }
        if saved.count > 1 {
            var path = Path()
            for (index, item) in saved.enumerated() {
                let point = chartPoint(months: item.months, value: item.value, plot: plot)
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            context.stroke(path, with: .color(accent), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }

        for item in plottedPoints {
            let point = chartPoint(months: item.months, value: item.value, plot: plot)
            let radius: CGFloat = item.isPreview ? 5.5 : 4
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(item.isPreview ? .white : accent))
            context.stroke(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(accent), lineWidth: item.isPreview ? 2.5 : 1.5)
        }
    }

    private func drawLabels(context: GraphicsContext, plot: CGRect) {
        for curve in GrowthReference.curvePercentiles {
            guard let endValue = GrowthReference.value(
                standard: standard,
                kind: kind,
                gender: gender,
                ageDays: maxMonths * 30.4375,
                zScore: curve.z
            ) else { continue }
            let point = chartPoint(months: maxMonths, value: endValue, plot: plot)
            context.draw(
                Text(curve.label.localized).font(.system(size: 7, weight: .semibold)).foregroundStyle(DesignToken.textSecondary.opacity(0.66)),
                at: CGPoint(x: plot.maxX - 2, y: point.y),
                anchor: .trailing
            )
        }

        let lower = yBounds.lowerBound
        let upper = yBounds.upperBound
        context.draw(Text(formatAxis(upper)).font(.system(size: 8, weight: .semibold)).foregroundStyle(DesignToken.textSecondary.opacity(0.68)), at: CGPoint(x: plot.minX - 5, y: plot.minY), anchor: .trailing)
        context.draw(Text(formatAxis(lower)).font(.system(size: 8, weight: .semibold)).foregroundStyle(DesignToken.textSecondary.opacity(0.68)), at: CGPoint(x: plot.minX - 5, y: plot.maxY), anchor: .trailing)
    }

    private func inspectGesture(plot: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard !plottedPoints.isEmpty else { return }
                let month = Double((gesture.location.x - plot.minX) / plot.width) * maxMonths
                selectedPoint = plottedPoints.min { abs($0.months - month) < abs($1.months - month) }
            }
            .onEnded { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeOut(duration: 0.2)) { selectedPoint = nil }
                }
            }
    }

    private func pointCallout(_ point: WHOGrowthPlotPoint) -> some View {
        HStack(spacing: 5) {
            Text(point.isPreview ? "本次" : AppDateTimeFormat.date(point.date))
            Text("\(String(format: "%.1f", point.value))\(kind.unit)")
                .foregroundStyle(accent)
        }
        .font(BBBFont.font(size: 9.5, weight: .bold))
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(Capsule().fill(DesignToken.surfaceRaised.opacity(0.92)).shadow(color: accent.opacity(0.10), radius: 8, y: 3))
    }

    private func chartPoint(months: Double, value: Double, plot: CGRect) -> CGPoint {
        let x = plot.minX + CGFloat(min(max(months / maxMonths, 0), 1)) * plot.width
        let fraction = (value - yBounds.lowerBound) / max(yBounds.upperBound - yBounds.lowerBound, 0.001)
        let y = plot.maxY - CGFloat(min(max(fraction, 0), 1)) * plot.height
        return CGPoint(x: x, y: y)
    }

    private func formatAxis(_ value: Double) -> String {
        kind == .weight ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}

private struct WHOGrowthPlotPoint: Identifiable, Hashable {
    let id: UUID
    let months: Double
    let value: Double
    let date: Date
    let isPreview: Bool
}

private extension View {
    func growthRecorderSurface(accent: Color) -> some View {
        background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [DesignToken.glassStroke.opacity(0.86), accent.opacity(0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: DesignToken.shadowColor.opacity(0.07), radius: 14, y: 7)
        )
    }
}
