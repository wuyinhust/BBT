import SwiftUI

struct HomeView: View {
    @Environment(BabyProfileStore.self) private var profileStore

    @Binding var selectedTab: RootTab
    @Binding var showBabyInfo: Bool
    @Binding var showCompanionPicker: Bool
    @State private var showChat = false
    @State private var showProfile = false
    @State private var now = Date()

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
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .navigationDestination(isPresented: $showChat) {
            BuddyChatView(showFeedSheet: .constant(false), showCompanionPicker: $showCompanionPicker)
        }
        .navigationDestination(isPresented: $showProfile) {
            ProfileView(showBabyInfo: $showBabyInfo)
        }
    }

    private var homeBackground: some View {
        return ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#F5F1FA"),
                    Color(hex: "#F8F7FB"),
                    Color(hex: "#EEF6FB")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .white.opacity(0.36),
                    .clear,
                    Color(hex: "#F4ECFA").opacity(0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(hex: "#FFFFFF").opacity(0.46),
                    Color(hex: "#FFFFFF").opacity(0.0)
                ],
                center: .top,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()
        }
    }

    private var topControls: some View {
        HStack(alignment: .top, spacing: 8) {
            babyAgeSummaryCard
                .layoutPriority(1)
            Spacer(minLength: 4)
            shortcutRow
        }
    }

    private var babyAgeSummaryCard: some View {
        Button {
            showProfile = true
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(todayDateText)
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(1)

                Text("\(profileStore.currentProfile.name)今天\(babyAgeText)了")
                    .font(BBBFont.font(size: 16, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 14)
            .frame(minWidth: 190, maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(.white.opacity(0.9))
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 12, y: 6)
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
            .fill(.white.opacity(0.92))
            .frame(width: 44, height: 44)
            .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 12, y: 5)
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
                .foregroundStyle(Color(hex: "#A9A6B9"))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .background(Capsule().fill(Color(hex: "#ECEBF3")))

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
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.05), radius: 16, y: 8)
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var todayDateText: String {
        let components = Calendar.current.dateComponents([.month, .day], from: now)
        return "今天是\(components.month ?? 1)月\(components.day ?? 1)日"
    }

    private var babyAgeText: String {
        let profile = profileStore.currentProfile
        let calendar = Calendar.current
        let startOfBirthDate = calendar.startOfDay(for: profile.birthDate)
        let startOfToday = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.year, .month, .day], from: startOfBirthDate, to: startOfToday)
        let years = max(components.year ?? 0, 0)
        let months = max(components.month ?? 0, 0)
        let days = max(components.day ?? 0, 0)

        if years > 0 {
            return "\(years)岁"
        }
        if months > 0 {
            return "\(months)月\(days)天"
        }

        return "\(days)天"
    }
}
