import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoFileName: String
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.pink.opacity(0.15))

            if let player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .onAppear { player.play() }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.pink)
                    Text("未找到动画视频")
                        .font(.headline)
                    Text("请将 \(videoFileName).mp4 放在 App Bundle 根目录")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .onChange(of: videoFileName) { _ in
            loadVideo()
        }
        .onAppear {
            loadVideo()
        }
    }

    private func loadVideo() {
        if let url = Bundle.main.url(forResource: videoFileName, withExtension: "mp4") {
            let newPlayer = AVPlayer(url: url)
            newPlayer.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in
                newPlayer.seek(to: .zero)
            }
            self.player = newPlayer
        } else {
            self.player = nil
        }
    }
}
