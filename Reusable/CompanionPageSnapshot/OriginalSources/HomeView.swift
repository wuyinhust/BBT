import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: RootTab
    @Binding var showBabyInfo: Bool
    @Binding var showCompanionPicker: Bool
    @State private var showChat = false
    @State private var showProfile = false

    var body: some View {
        GeometryReader { proxy in
            let reservedBottomSpace: CGFloat = 168
            let availableHeight = max(proxy.size.height - reservedBottomSpace, 360)
            let stageHeight = min(max(availableHeight * 0.48, 220), 350)

            ZStack {
                homeBackground

                VStack(spacing: 0) {
                    topControls
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    Spacer(minLength: 20)
                    greetingText
                    Spacer(minLength: 6)
                    animationStage
                        .frame(height: stageHeight)
                        .padding(.horizontal, 8)

                    Spacer(minLength: 18)
                }
                .frame(width: proxy.size.width, height: availableHeight, alignment: .top)
                .padding(.bottom, reservedBottomSpace)
                .clipped()
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .safeAreaInset(edge: .bottom) {
            chatEntry
                .padding(.horizontal, 16)
                    .padding(.bottom, 8)
        }
        .navigationDestination(isPresented: $showChat) {
            BuddyChatView(showFeedSheet: .constant(false), showCompanionPicker: $showCompanionPicker)
        }
        .navigationDestination(isPresented: $showProfile) {
            MyPageView()
        }
    }

    private var homeBackground: some View {
        HomeSoftBackground()
    }

    private var topControls: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer(minLength: 0)
            shortcutRow
        }
    }

    private var greetingText: some View {
        HStack(spacing: 8) {
            Text("✦")
                .foregroundStyle(DesignToken.primary)
            Text("今天也一起照顾宝宝")
                .font(BBBFont.font(size: 20, weight: .semibold))
                .foregroundStyle(DesignToken.textPrimary)
            Text("✦")
                .foregroundStyle(DesignToken.primary)
        }
        .shadow(color: .white.opacity(0.7), radius: 8)
    }

    private var animationStage: some View {
        GeometryReader { proxy in
            ZStack {
                let imageSide = min(proxy.size.width, proxy.size.height) * 0.98

                Group {
                    if UIImage(named: "home_background") != nil {
                        Image("home_background")
                            .resizable()
                            .scaledToFit()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(DesignToken.primary.opacity(0.72))
                            Text("中央主视觉")
                                .font(BBBFont.font(size: 13, weight: .bold))
                                .foregroundStyle(DesignToken.textSecondary)
                        }
                        .opacity(0.5)
                    }
                }
                .frame(width: imageSide, height: imageSide)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity)
    }

    private var shortcutRow: some View {
        HStack(spacing: 8) {
            Button { showProfile = true } label: {
                circleShortcut(icon: "person.crop.circle.fill")
            }
            NavigationLink(destination: DailyMessageView()) {
                circleShortcut(icon: "envelope.fill")
            }
            Button { selectedTab = .record } label: {
                circleShortcut(icon: "book.fill")
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func circleShortcut(icon: String) -> some View {
        Circle()
            .fill(DesignToken.surfaceRaised.opacity(0.92))
            .frame(width: 44, height: 44)
            .shadow(color: DesignToken.shadowColor.opacity(0.16), radius: 12, y: 5)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
            )
    }

    private var chatEntry: some View {
        Button {
            showChat = true
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "message.fill")
                Text("和 buddy 聊聊天吧...")
                    .lineLimit(1)
                }
                .font(BBBFont.font(size: 13, weight: .semibold))
                .foregroundStyle(DesignToken.textFaint)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .background(Capsule().fill(DesignToken.surfaceSoft))

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignToken.primary, DesignToken.easyActivity],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "mic.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(DesignToken.onPrimary))
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignToken.surface)
                    .shadow(color: DesignToken.shadowColor.opacity(0.14), radius: 16, y: 8)
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }

}

struct HomeSoftBackground: View {
    var body: some View {
        DesignToken.canvas
            .ignoresSafeArea()
    }
}
