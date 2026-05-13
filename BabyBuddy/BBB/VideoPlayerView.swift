import SwiftUI
import AVKit

struct VideoPlayerView: View {
    enum PlayerStyle {
        case card
        case fullscreen
    }

    let videoFileName: String
    var style: PlayerStyle = .card
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player {
                switch style {
                case .card:
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .background(RoundedRectangle(cornerRadius: 24).fill(.pink.opacity(0.15)))
                        .onAppear { player.play() }
                case .fullscreen:
                    FullscreenAVPlayerView(player: player)
                        .background(.black)
                        .onAppear { player.play() }
                }
            } else {
                placeholder
            }
        }
        .onChange(of: videoFileName) {
            loadVideo()
        }
        .onAppear {
            loadVideo()
        }
    }

    private var placeholder: some View {
        ZStack {
            switch style {
            case .card:
                RoundedRectangle(cornerRadius: 24)
                    .fill(.pink.opacity(0.15))
            case .fullscreen:
                Color.black
            }

            VStack(spacing: 12) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(DesignToken.primary)
                    .symbolEffect(.pulse)
                Text("等待视频资源")
                    .font(.headline)
                    .foregroundStyle(style == .fullscreen ? .white : DesignToken.textPrimary)
                Text("\(videoFileName).mp4")
                    .font(.caption)
                    .foregroundStyle(style == .fullscreen ? .white.opacity(0.65) : .secondary)
                Text("请将视频放入 Videos/ 子目录或 App Bundle 根目录")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(style == .fullscreen ? .white.opacity(0.55) : .secondary)
            }
            .padding()
        }
    }

    private func loadVideo() {
        let url = Bundle.main.url(forResource: videoFileName, withExtension: "mp4", subdirectory: "Videos")
            ?? Bundle.main.url(forResource: videoFileName, withExtension: "mp4")

        if let url {
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

private struct FullscreenAVPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        playerLayer.videoGravity = .resizeAspectFill
    }
}
