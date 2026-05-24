import SwiftUI

struct BuddyChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var activityStore: ActivityStore

    @Binding var showFeedSheet: Bool
    @Binding var showCompanionPicker: Bool

    @State private var currentAction: BabyAction = .idle
    @State private var messageText = ""
    @State private var petResetTask: DispatchWorkItem?

    var body: some View {
        ZStack {
            VideoPlayerView(videoFileName: videoFileName, style: .fullscreen)
                .ignoresSafeArea()

            gestureOverlay

            VStack(spacing: 0) {
                topBar
                Spacer()
            }
        }
        .background(Color.black)
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var videoFileName: String {
        "\(companionStore.selectedID)_\(currentAction.rawValue)"
    }

    private var gestureOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard abs(value.translation.width) + abs(value.translation.height) > 8 else { return }
                        triggerPet()
                    }
                    .onEnded { value in
                        if abs(value.translation.width) + abs(value.translation.height) <= 8 {
                            trigger(.poke)
                        } else {
                            schedulePetEnd()
                        }
                    }
            )
            .overlay {
                ShakeDetector {
                    trigger(.shake)
                }
            }
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 14) {
            Button { dismiss() } label: {
                circleShortcut(icon: "chevron.left")
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            Button { showCompanionPicker = true } label: {
                circleShortcut(icon: "person.2.circle.fill")
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                TextField("和 buddy 聊聊天吧...", text: $messageText)
            }
            .font(BBBFont.font(size: 13, weight: .semibold))
            .foregroundStyle(Color(hex: "#A9A6B9"))
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(Capsule().fill(Color(hex: "#ECEBF3")))

            Button {
                trigger(.listen)
            } label: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#BDA6F2"), Color(hex: "#E9B2D1")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "mic.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.95))
                .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 16, y: 8)
        )
    }

    private func circleShortcut(icon: String) -> some View {
        Circle()
            .fill(.white.opacity(0.92))
            .frame(width: 48, height: 48)
            .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 12, y: 5)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
            )
    }

    private func triggerPet() {
        guard currentAction != .pet else {
            schedulePetEnd()
            return
        }
        trigger(.pet)
        schedulePetEnd()
    }

    private func schedulePetEnd() {
        petResetTask?.cancel()
        let task = DispatchWorkItem {
            if currentAction == .pet {
                currentAction = .idle
            }
        }
        petResetTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: task)
    }

    private func triggerRecord(_ action: BabyAction) {
        activityStore.record(action)
        trigger(action)
    }

    private func trigger(_ action: BabyAction) {
        currentAction = action
        if action.isRecordable {
            activityStore.record(action)
        }
        guard action.duration > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + action.duration) {
            if currentAction == action {
                currentAction = .idle
            }
        }
    }
}
