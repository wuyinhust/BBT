import SwiftUI

struct RecordView: View {
    @EnvironmentObject private var store: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore

    @Binding var showFeedSheet: Bool
    @State private var selectedDate = Date()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    weekCalendar
                    summaryCard
                    entriesSection
                    Spacer(minLength: 112)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
            .background(DesignToken.background.ignoresSafeArea())

            Button { showFeedSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(DesignToken.primaryGradient))
                    .shadow(color: DesignToken.primary.opacity(0.35), radius: 14, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.trailing, 22)
            .padding(.bottom, 96)
        }
    }

    private var selectedSessions: [FeedingSession] {
        store.sessions(on: selectedDate)
    }

    private var selectedRecords: [RecordListItem] {
        let feedingItems = selectedSessions.map { RecordListItem.feeding($0) }
        let careItems = activityStore.careRecords(on: selectedDate).map { RecordListItem.care($0) }
        return (feedingItems + careItems).sorted { $0.date > $1.date }
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
            ?? calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    moveWeek(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                }
                Spacer()
                Text(weekTitle)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Button {
                    moveWeek(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(DesignToken.textPrimary)

            HStack(spacing: 8) {
                ForEach(weekDates, id: \.self) { date in
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                            selectedDate = date
                        }
                    } label: {
                        dayCell(date)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当天记录")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Text("\(selectedRecords.count) 条")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            if selectedRecords.isEmpty {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "tray",
                    description: Text("点击右下角按钮添加一次喂养")
                )
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
            } else {
                ForEach(selectedRecords) { record in
                    switch record {
                    case .feeding(let session):
                        sessionRow(session)
                    case .care(let careRecord):
                        careRecordRow(careRecord)
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: 2) {
                    Text(selectedDate, format: .dateTime.day())
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                    Text(selectedDate, format: .dateTime.month(.abbreviated))
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color(hex: "#D4A62F"))
                .frame(width: 62, height: 70)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#FFF6D8")))

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(Calendar.current.isDateInToday(selectedDate) ? "今日概览" : "当天概览")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricTile(title: "喂养", value: "\(store.feedCount(on: selectedDate))次", icon: "babybottle.fill", color: DesignToken.primary)
                metricTile(title: "母乳", value: "\(store.breastDuration(on: selectedDate))min", icon: "drop.fill", color: Color(hex: "#67C587"))
                metricTile(title: "奶粉", value: "\(store.formulaML(on: selectedDate))ml", icon: "waterbottle.fill", color: Color(hex: "#6DA5F2"))
                metricTile(title: "辅食", value: "\(store.solidsGram(on: selectedDate))g", icon: "fork.knife", color: Color(hex: "#F0A85B"))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(Circle().fill(color.opacity(0.13)))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignToken.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#F8F7FB")))
    }

    private func sessionRow(_ session: FeedingSession) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(session.type.accent.opacity(0.13))
                .frame(width: 52, height: 52)
                .overlay(Image(systemName: sessionIcon(for: session)).font(.system(size: 22, weight: .bold)).foregroundStyle(session.type.accent))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.type.displayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(detail(for: session))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(time(session.createdAt))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
    }

    private func careRecordRow(_ record: CareRecord) -> some View {
        let accent = careRecordAccent(for: record.kind)
        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.13))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: careRecordIcon(for: record.kind))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(record.detail)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(time(record.recordedAt))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
    }

    private func sessionIcon(for session: FeedingSession) -> String {
        switch session.type {
        case .bottle: return "babybottle.fill"
        case .breast: return "drop.fill"
        case .solid: return "leaf.fill"
        }
    }

    private func detail(for session: FeedingSession) -> String {
        switch session.type {
        case .bottle:
            let amount = session.amountML.map { "\($0)ml" } ?? ""
            let duration = session.bottleDurationMin.map { "\($0)分钟" } ?? ""
            return [amount, duration].filter { !$0.isEmpty }.joined(separator: " · ")
        case .breast:
            return session.durationMin.map { "\($0)分钟" } ?? "0分钟"
        case .solid:
            let kind = session.solidsKind ?? "辅食"
            let gram = session.solidsGram.map { "\($0)g" } ?? ""
            return [kind, gram].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func careRecordIcon(for kind: CareRecordKind) -> String {
        switch kind {
        case .diaper: return "drop.fill"
        case .sleep: return "moon.fill"
        }
    }

    private func careRecordAccent(for kind: CareRecordKind) -> Color {
        switch kind {
        case .diaper: return Color(hex: "#67C587")
        case .sleep: return Color(hex: "#6DA5F2")
        }
    }

    private func moveWeek(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .weekOfYear, value: value, to: selectedDate) else { return }
        selectedDate = next
    }

    private var weekTitle: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDate(first, equalTo: last, toGranularity: .month) ? "M月" : "M月d日"
        if Calendar.current.isDate(first, equalTo: last, toGranularity: .month) {
            return formatter.string(from: first)
        }
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "M月d日"
        return "\(formatter.string(from: first)) - \(endFormatter.string(from: last))"
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)

        return VStack(spacing: 7) {
            Text(weekdaySymbol(for: date))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? .white.opacity(0.86) : DesignToken.textSecondary)
            Text(date, format: .dateTime.day())
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(isSelected ? .white : DesignToken.textPrimary)
            Circle()
                .fill(isToday ? (isSelected ? .white : DesignToken.primary) : .clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? DesignToken.primary : Color(hex: "#F8F7FB"))
        )
    }

    private func weekdaySymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

private enum RecordListItem: Identifiable {
    case feeding(FeedingSession)
    case care(CareRecord)

    var id: String {
        switch self {
        case .feeding(let session): return "feeding-\(session.id.uuidString)"
        case .care(let record): return "care-\(record.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .feeding(let session): return session.createdAt
        case .care(let record): return record.recordedAt
        }
    }
}
