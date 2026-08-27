import SwiftUI
import AVKit

private enum VideoRenderPalette {
    static let playbackCanvas = Color.black // color-audit: allow-fixed video playback canvas
    static let onPlayback = Color.white // color-audit: allow-fixed video playback foreground
}

struct VideoPlayerView: View {
    enum PlayerStyle {
        case card
        case fullscreen
    }

    let videoFileName: String
    var style: PlayerStyle = .card
    @State private var player: AVPlayer?
    @State private var playbackEndObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            if let player {
                switch style {
                case .card:
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .background(RoundedRectangle(cornerRadius: 24).fill(DesignToken.easyActivitySoft))
                        .onAppear { player.play() }
                case .fullscreen:
                    FullscreenAVPlayerView(player: player)
                        .background(VideoRenderPalette.playbackCanvas)
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
        .onDisappear {
            releasePlayer()
        }
    }

    private var placeholder: some View {
        ZStack {
            switch style {
            case .card:
                RoundedRectangle(cornerRadius: 24)
                    .fill(DesignToken.easyActivitySoft)
            case .fullscreen:
                VideoRenderPalette.playbackCanvas
            }

            VStack(spacing: 12) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(DesignToken.primary)
                    .symbolEffect(.pulse)
                Text("等待视频资源")
                    .font(BBBFont.font(size: 15, weight: .semibold))
                    .foregroundStyle(style == .fullscreen ? VideoRenderPalette.onPlayback : DesignToken.textPrimary)
                Text("\(videoFileName).mp4")
                    .font(BBBFont.font(size: 12, weight: .regular))
                    .foregroundStyle(style == .fullscreen ? VideoRenderPalette.onPlayback.opacity(0.65) : DesignToken.textMuted)
                Text("请将视频放入 Videos/ 子目录或 App Bundle 根目录")
                    .font(BBBFont.font(size: 11, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(style == .fullscreen ? VideoRenderPalette.onPlayback.opacity(0.55) : DesignToken.textMuted)
            }
            .padding()
        }
    }

    private func loadVideo() {
        releasePlayer()
        let url = Bundle.main.url(forResource: videoFileName, withExtension: "mp4", subdirectory: "Videos")
            ?? Bundle.main.url(forResource: videoFileName, withExtension: "mp4")

        if let url {
            let newPlayer = AVPlayer(url: url)
            newPlayer.actionAtItemEnd = .none
            playbackEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { [weak newPlayer] _ in
                newPlayer?.seek(to: .zero)
            }
            self.player = newPlayer
        } else {
            self.player = nil
        }
    }

    private func releasePlayer() {
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
        player?.pause()
        player = nil
    }
}

private struct FullscreenAVPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer?.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer?.player = player
    }
}

private final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer? {
        layer as? AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer?.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        playerLayer?.videoGravity = .resizeAspectFill
    }
}
