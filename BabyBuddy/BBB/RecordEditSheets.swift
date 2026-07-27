import SwiftUI

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
                            Text(record.kind.unit.localized)
                                .font(BBBFont.font(size: 22, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary)
                        }

                        Slider(value: $value, in: valueRange, step: 0.1)
                            .tint(record.kind.accent)

                        Stepper("调整\(record.kind.title)", value: $value, in: valueRange, step: 0.1)
                            .labelsHidden()
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignToken.surfaceRaised))

                    DatePicker("时间", selection: $recordedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .font(BBBFont.font(size: 17, weight: .semibold))
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignToken.surfaceRaised))

                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignToken.surfaceRaised))

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
        DesignToken.canvas.ignoresSafeArea()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DesignToken.onPrimary)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(accent))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title.localized)
                            .font(BBBFont.font(size: 22, weight: .bold))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(subtitle.localized)
                            .font(BBBFont.font(size: 13, weight: .medium))
                            .foregroundStyle(DesignToken.textSecondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(DesignToken.surface))

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
            .foregroundStyle(DesignToken.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(color))
    }
    .buttonStyle(ScaleButtonStyle())
}
