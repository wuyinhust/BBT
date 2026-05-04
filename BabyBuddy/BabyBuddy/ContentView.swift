import SwiftUI

struct ContentView: View {
    @StateObject private var store = ActivityStore()

    private let companions: [BabyCompanion] = [
        BabyCompanion(id: "bunny", name: "Mochi", species: "兔宝宝"),
        BabyCompanion(id: "bear", name: "Coco", species: "熊宝宝"),
        BabyCompanion(id: "fox", name: "Lulu", species: "狐宝宝")
    ]

    @State private var selectedCompanion: BabyCompanion = BabyCompanion(id: "bunny", name: "Mochi", species: "兔宝宝")
    @State private var currentAction: BabyAction = .nursing

    private var currentVideo: String {
        selectedCompanion.videoName(for: currentAction)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("伙伴", selection: $selectedCompanion) {
                    ForEach(companions) { companion in
                        Text("\(companion.name) · \(companion.species)").tag(companion)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                VideoPlayerView(videoFileName: currentVideo)
                    .frame(height: 280)
                    .padding(.horizontal)
                    .onTapGesture { trigger(.tap) }

                Text("轻触动画区域或摇晃手机可触发互动")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    actionButton(.nursing, color: .blue)
                    actionButton(.diaper, color: .green)
                    actionButton(.sleep, color: .indigo)
                }
                .padding(.horizontal)

                Button {
                    // phase-2 placeholder
                } label: {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.pink)
                }

                List(store.logs.prefix(10)) { log in
                    HStack {
                        Label(log.action.title, systemImage: log.action.systemImage)
                        Spacer()
                        Text(log.timestamp, style: .time)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Baby Buddy")
            .background(ShakeDetector {
                trigger(.shake)
            })
        }
    }

    private func actionButton(_ action: BabyAction, color: Color) -> some View {
        Button {
            trigger(action)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: action.systemImage)
                    .font(.title2)
                Text(action.title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func trigger(_ action: BabyAction) {
        currentAction = action
        if [.nursing, .diaper, .sleep].contains(action) {
            store.record(action)
        }
    }
}
