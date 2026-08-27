import SwiftUI
import UIKit

enum BBBuddyAppSharing {
    /// Before publication this still opens the App Store search page, so the
    /// share sheet sends a link instead of a generated .txt attachment.
    static let preLaunchSearchURL = URL(
        string: "itms-apps://itunes.apple.com/search?term=BBBuddy"
    )

    // TODO(AppStore): replace this nil with the published product URL, for example:
    // https://apps.apple.com/cn/app/bbbuddy/idXXXXXXXXXX
    static let publishedProductURL: URL? = nil

    static var activityItems: [Any] {
        if let url = publishedProductURL ?? preLaunchSearchURL {
            return [url]
        }
        return ["BBBuddy"]
    }
}

struct BBBuddyShareRequest: Identifiable {
    let id = UUID()
    let activityItems: [Any]

    init(activityItems: [Any] = BBBuddyAppSharing.activityItems) {
        self.activityItems = activityItems
    }
}

struct BBBuddySystemShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onCompletion: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onCompletion(completed)
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(
                x: controller.view.bounds.midX,
                y: controller.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SharePlusCampaignView: View {
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @State private var shareRequest: BBBuddyShareRequest?
    @State private var notice: SharePlusCampaignNotice?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DesignToken.sectionSpacing) {
                heroCard
                stepsCard
                rulesCard
            }
            .padding(DesignToken.screenHorizontalPadding)
            .padding(.vertical, 18)
        }
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle(BBBuddyLegalCopy.sharePlusTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .sheet(item: $shareRequest) { request in
            BBBuddySystemShareSheet(activityItems: request.activityItems) { completed in
                guard completed else { return }
                handleCompletedShare()
            }
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(BBBuddyLegalCopy.gotIt))
            )
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(DesignToken.primaryGradient))

                VStack(alignment: .leading, spacing: 5) {
                    Text(BBBuddyLegalCopy.shareThirtyDays)
                        .font(BBBFont.font(size: 22, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(BBBuddyLegalCopy.shareThirtyDaysDetail)
                        .font(BBBFont.font(size: 12.5, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Label(statusText, systemImage: statusIcon)
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Capsule().fill(statusColor.opacity(0.11)))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softProfileCard(cornerRadius: 26)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(BBBuddyLegalCopy.howToJoin)
                .font(BBBFont.font(size: 17, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            campaignStep(
                number: "1",
                title: BBBuddyLegalCopy.stepShareTitle,
                detail: BBBuddyLegalCopy.stepShareDetail
            )
            campaignStep(
                number: "2",
                title: BBBuddyLegalCopy.stepCompleteTitle,
                detail: BBBuddyLegalCopy.stepCompleteDetail
            )
            campaignStep(
                number: "3",
                title: BBBuddyLegalCopy.stepEnjoyTitle,
                detail: BBBuddyLegalCopy.stepEnjoyDetail
            )
        }
        .padding(16)
        .softProfileCard(cornerRadius: DesignToken.largeCardRadius)
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(BBBuddyLegalCopy.activityRules, systemImage: "checkmark.shield.fill")
                .font(BBBFont.font(size: 15, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            ForEach(BBBuddyLegalCopy.activityRuleItems, id: \.self) { rule in
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(DesignToken.primary)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(rule)
                        .font(BBBFont.font(size: 12, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            NavigationLink {
                BBBuddyTermsOfUseView()
            } label: {
                Text(BBBuddyLegalCopy.readActivityTerms)
                    .font(BBBFont.font(size: 12, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
                    .frame(maxWidth: .infinity, minHeight: DesignToken.minimumTapSize)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .softProfileCard(cornerRadius: DesignToken.largeCardRadius)
    }

    private var actionBar: some View {
        VStack(spacing: 6) {
            Button {
                shareRequest = BBBuddyShareRequest()
            } label: {
                Label(actionTitle, systemImage: actionIcon)
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(DesignToken.primaryGradient))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isActionDisabled)
            .opacity(isActionDisabled ? 0.56 : 1)
            .accessibilityIdentifier("plus.shareReward.action")

            Text(BBBuddyLegalCopy.noSubscriptionCharge)
                .font(BBBFont.font(size: 9.5, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignToken.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func campaignStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DesignToken.primary))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(detail)
                    .font(BBBFont.font(size: 11.5, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var isActionDisabled: Bool {
        membershipStore.activePlan != nil || membershipStore.hasClaimedShareReward
    }

    private var actionTitle: String {
        if membershipStore.activePlan != nil {
            return BBBuddyLegalCopy.plusAlreadyActive
        }
        if membershipStore.isShareRewardActive {
            return BBBuddyLegalCopy.rewardAlreadyClaimed
        }
        if membershipStore.hasClaimedShareReward {
            return BBBuddyLegalCopy.rewardUsed
        }
        return BBBuddyLegalCopy.shareAndClaim
    }

    private var actionIcon: String {
        isActionDisabled ? "checkmark.circle.fill" : "square.and.arrow.up"
    }

    private var statusText: String {
        if let activePlan = membershipStore.activePlan {
            return BBBuddyLegalCopy.format(
                BBBuddyLegalCopy.paidPlusStatusFormat,
                activePlan.title.localized
            )
        }
        if membershipStore.isShareRewardActive,
           let expirationDate = membershipStore.shareRewardExpirationDate {
            return BBBuddyLegalCopy.format(
                BBBuddyLegalCopy.rewardValidUntilFormat,
                AppDateTimeFormat.date(expirationDate)
            )
        }
        if membershipStore.hasClaimedShareReward {
            return BBBuddyLegalCopy.rewardExpired
        }
        return BBBuddyLegalCopy.rewardAvailable
    }

    private var statusIcon: String {
        membershipStore.isPlusActive ? "checkmark.circle.fill" : "gift.fill"
    }

    private var statusColor: Color {
        membershipStore.isPlusActive ? DesignToken.success : DesignToken.primary
    }

    private func handleCompletedShare() {
        switch membershipStore.claimShareReward() {
        case .activated(let expirationDate):
            notice = SharePlusCampaignNotice(
                title: BBBuddyLegalCopy.claimSuccess,
                message: BBBuddyLegalCopy.format(
                    BBBuddyLegalCopy.claimSuccessDetailFormat,
                    AppDateTimeFormat.date(expirationDate)
                )
            )
        case .paidPlusActive:
            notice = SharePlusCampaignNotice(
                title: BBBuddyLegalCopy.plusAlreadyActive,
                message: BBBuddyLegalCopy.paidPlusNotOverwritten
            )
        case .alreadyClaimed(let expirationDate):
            let message = expirationDate.map {
                BBBuddyLegalCopy.format(
                    BBBuddyLegalCopy.rewardClaimedBeforeFormat,
                    AppDateTimeFormat.date($0)
                )
            } ?? BBBuddyLegalCopy.rewardUsed
            notice = SharePlusCampaignNotice(
                title: BBBuddyLegalCopy.rewardAlreadyClaimed,
                message: message
            )
        }
    }
}

private struct SharePlusCampaignNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct BBBuddyPrivacyPolicyView: View {
    var body: some View {
        BBBuddyLegalDocumentView(
            title: BBBuddyLegalCopy.privacyTitle,
            effectiveDate: BBBuddyLegalCopy.effectiveDate,
            introduction: BBBuddyLegalCopy.privacyIntroduction,
            sections: BBBuddyLegalCopy.privacySections
        )
    }
}

struct BBBuddyTermsOfUseView: View {
    private static let appleStandardEULAURL = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    ) ?? URL(fileURLWithPath: "/")

    var body: some View {
        BBBuddyLegalDocumentView(
            title: BBBuddyLegalCopy.termsTitle,
            effectiveDate: BBBuddyLegalCopy.effectiveDate,
            introduction: BBBuddyLegalCopy.termsIntroduction,
            sections: BBBuddyLegalCopy.termsSections,
            footerLink: .init(
                title: BBBuddyLegalCopy.appleStandardTerms,
                url: Self.appleStandardEULAURL
            )
        )
    }
}

private struct BBBuddyLegalDocumentView: View {
    struct FooterLink {
        let title: String
        let url: URL
    }

    let title: String
    let effectiveDate: String
    let introduction: String
    let sections: [(title: String, body: String)]
    var footerLink: FooterLink? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(effectiveDate)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(introduction)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    legalSection(section.title, body: section.body)
                }

                if let footerLink {
                    Link(destination: footerLink.url) {
                        Label(footerLink.title, systemImage: "arrow.up.right.square")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legalSection(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum BBBuddyLegalCopy {
    static func value(_ simplifiedChinese: String, _ traditionalChinese: String, _ english: String) -> String {
        switch AppLocalization.language {
        case .simplifiedChinese: return simplifiedChinese
        case .traditionalChinese: return traditionalChinese
        case .english: return english
        }
    }

    static func format(_ format: String, _ value: String) -> String {
        String(format: format, locale: AppLocalization.locale, value)
    }

    static var gotIt: String { value("知道了", "知道了", "Got it") }
    static var legalAndSharingTitle: String { value("分享与法律", "分享與法律", "Sharing & Legal") }
    static var shareAppTitle: String { value("分享 App 给朋友", "分享 App 給朋友", "Share the App") }
    static var shareAppSubtitle: String { value("发送 App Store 链接，不分享宝宝资料", "傳送 App Store 連結，不分享寶寶資料", "Share an App Store link without baby data") }
    static var shareCampaignSubtitle: String { value("完成分享，领取一次 30 天体验", "完成分享，領取一次 30 天體驗", "Complete a share to claim one 30-day trial") }
    static var privacySubtitle: String { value("了解数据与权限的处理方式", "了解資料與權限的處理方式", "Learn how data and permissions are handled") }
    static var termsSubtitle: String { value("使用规则、Plus 购买与活动条款", "使用規則、Plus 購買與活動條款", "Usage rules, Plus purchases, and campaign terms") }
    static var sharePlusTitle: String { value("分享领 Plus", "分享領 Plus", "Share for Plus") }
    static var shareThirtyDays: String { value("分享一次，领 30 天 Plus", "分享一次，領 30 天 Plus", "Share once, get 30 days of Plus") }
    static var shareThirtyDaysDetail: String { value("把 BBBuddy 推荐给需要的朋友，完成系统分享后即可领取一次体验。", "把 BBBuddy 推薦給需要的朋友，完成系統分享後即可領取一次體驗。", "Recommend BBBuddy to someone who may need it. Complete the system share to claim a one-time trial.") }
    static var howToJoin: String { value("参与方式", "參與方式", "How it works") }
    static var stepShareTitle: String { value("分享 BBBuddy", "分享 BBBuddy", "Share BBBuddy") }
    static var stepShareDetail: String { value("使用系统分享面板，把 App Store 链接发送给朋友或家庭成员。", "使用系統分享面板，把 App Store 連結傳送給朋友或家庭成員。", "Use the system share sheet to send the App Store link to a friend or family member.") }
    static var stepCompleteTitle: String { value("完成系统分享", "完成系統分享", "Complete the system share") }
    static var stepCompleteDetail: String { value("只有系统返回“已完成”后才会发放；取消分享不会消耗活动资格。", "只有系統回傳「已完成」後才會發放；取消分享不會消耗活動資格。", "The reward is issued only after iOS reports completion. Cancelling does not use your eligibility.") }
    static var stepEnjoyTitle: String { value("立即体验 Plus", "立即體驗 Plus", "Enjoy Plus immediately") }
    static var stepEnjoyDetail: String { value("30 天体验立即生效，到期自动结束，不收费、不自动续订。", "30 天體驗立即生效，到期自動結束，不收費、不自動續訂。", "Your 30-day trial starts immediately and ends automatically, with no charge or renewal.") }
    static var activityRules: String { value("活动规则", "活動規則", "Campaign rules") }
    static var activityRuleItems: [String] {
        [
            value("本次安装仅可领取一次，体验从领取成功时开始计算。", "本次安裝僅可領取一次，體驗從領取成功時開始計算。", "One reward per app installation, beginning when the claim succeeds."),
            value("活动体验不是 App Store 订阅，不会产生扣费，也不会延长现有付费方案。", "活動體驗不是 App Store 訂閱，不會產生扣費，也不會延長現有付費方案。", "The reward is not an App Store subscription, creates no charge, and does not extend a paid plan."),
            value("分享内容只有 App Store 链接，不包含宝宝资料、记录或照片。", "分享內容只有 App Store 連結，不包含寶寶資料、記錄或照片。", "The share contains only an App Store link—never baby profiles, records, or photos."),
            value("Apple 不是本活动的赞助方，也不负责活动权益的发放。", "Apple 不是本活動的贊助方，也不負責活動權益的發放。", "Apple is not a sponsor of this campaign and does not issue its reward.")
        ]
    }
    static var readActivityTerms: String { value("查看完整使用条款", "查看完整使用條款", "Read the full Terms of Use") }
    static var noSubscriptionCharge: String { value("本活动不会发起购买或自动续费", "本活動不會發起購買或自動續費", "This campaign does not start a purchase or auto-renewal") }
    static var plusAlreadyActive: String { value("Plus 已开通", "Plus 已開通", "Plus is already active") }
    static var rewardAlreadyClaimed: String { value("体验已领取", "體驗已領取", "Trial claimed") }
    static var rewardUsed: String { value("本次活动资格已使用", "本次活動資格已使用", "This campaign reward has been used") }
    static var shareAndClaim: String { value("分享并领取 30 天 Plus", "分享並領取 30 天 Plus", "Share and claim 30 days of Plus") }
    static var paidPlusStatusFormat: String { value("当前为%@ Plus", "目前為%@ Plus", "Current plan: %@ Plus") }
    static var rewardValidUntilFormat: String { value("Plus 体验有效至 %@", "Plus 體驗有效至 %@", "Plus trial valid until %@") }
    static var rewardExpired: String { value("30 天 Plus 体验已结束", "30 天 Plus 體驗已結束", "Your 30-day Plus trial has ended") }
    static var rewardAvailable: String { value("本次安装可领取一次", "本次安裝可領取一次", "One claim is available for this installation") }
    static var claimSuccess: String { value("Plus 体验已生效", "Plus 體驗已生效", "Plus trial activated") }
    static var claimSuccessDetailFormat: String { value("现在可以使用 Plus 权益，有效至 %@。", "現在可以使用 Plus 權益，有效至 %@。", "Plus benefits are now available through %@.") }
    static var paidPlusNotOverwritten: String { value("你现有的 App Store Plus 权益保持不变。", "你現有的 App Store Plus 權益保持不變。", "Your existing App Store Plus entitlement remains unchanged.") }
    static var rewardClaimedBeforeFormat: String { value("本次安装已领取过活动体验，记录的到期日为 %@。", "本次安裝已領取過活動體驗，記錄的到期日為 %@。", "This installation already claimed the campaign trial. Its recorded expiration date is %@.") }

    static var privacyTitle: String { value("隐私政策", "隱私政策", "Privacy Policy") }
    static var termsTitle: String { value("使用条款", "使用條款", "Terms of Use") }
    static var effectiveDate: String { value("生效日期：2026 年 8 月 12 日", "生效日期：2026 年 8 月 12 日", "Effective: August 12, 2026") }
    static var privacyIntroduction: String { value("BBBuddy 重视家庭与宝宝资料的私密性。本政策说明应用处理哪些数据、为什么处理，以及你可以如何控制这些数据。", "BBBuddy 重視家庭與寶寶資料的私密性。本政策說明應用程式處理哪些資料、為什麼處理，以及你可以如何控制這些資料。", "BBBuddy respects the privacy of families and baby information. This policy explains what the app processes, why it does so, and how you can control that data.") }
    static var privacySections: [(title: String, body: String)] {
        [
            (value("1. 我们处理的数据", "1. 我們處理的資料", "1. Data we process"), value("你主动录入的宝宝资料、喂养、睡眠、护理、成长、主观状态和里程碑等记录会保存在设备上。你选择的照片、视频或语音仅用于对应功能。BBBuddy 不出售个人数据，不接入第三方广告，也不进行跨应用追踪。", "你主動輸入的寶寶資料、餵養、睡眠、護理、成長、主觀狀態和里程碑等記錄會儲存在裝置上。你選擇的照片、影片或語音僅用於對應功能。BBBuddy 不出售個人資料，不接入第三方廣告，也不進行跨應用程式追蹤。", "Baby profiles and the feeding, sleep, care, growth, subjective-state, and milestone records you enter are stored on your device. Photos, videos, or voice you choose are used only for their related features. BBBuddy does not sell personal data, include third-party advertising, or track you across apps.")),
            (value("2. 本机保存", "2. 本機儲存", "2. On-device storage"), value("当前版本的宝宝资料、记录与媒体保存在本机，不提供家庭同步或家庭共享入口。你可以在应用内管理记录，并通过数据导入导出功能保存副本。", "目前版本的寶寶資料、記錄與媒體儲存在本機，不提供家庭同步或家庭分享入口。你可以在應用程式內管理記錄，並透過資料匯入匯出功能保留副本。", "In the current version, baby information, records, and media are stored on your device. Family sync and sharing are not available. You can manage records in the app and keep copies through data import and export.")),
            (value("3. 系统权限", "3. 系統權限", "3. System permissions"), value("相机、照片、麦克风、语音识别、运动和通知权限只在相关功能需要时请求。你可以在 iOS 设置中随时关闭权限。关闭权限可能使对应功能不可用，但不会影响无关功能。", "相機、照片、麥克風、語音辨識、動作與通知權限只在相關功能需要時請求。你可以在 iOS 設定中隨時關閉權限。關閉權限可能使對應功能無法使用，但不會影響無關功能。", "Camera, photo, microphone, speech-recognition, motion, and notification access is requested only when a related feature needs it. You can disable access in iOS Settings at any time. Disabling access may stop that feature from working but does not affect unrelated features.")),
            (value("4. 购买", "4. 購買", "4. Purchases"), value("App Store 负责处理 Plus 购买、交易验证和订阅状态。BBBuddy 不接收你的完整付款卡信息。", "App Store 負責處理 Plus 購買、交易驗證和訂閱狀態。BBBuddy 不接收你的完整付款卡資訊。", "The App Store handles Plus purchases, transaction verification, and subscription status. BBBuddy does not receive your full payment-card details.")),
            (value("5. 保存、删除与安全", "5. 保存、刪除與安全", "5. Retention, deletion, and security"), value("记录会保留到你在应用中删除、清除应用数据或卸载应用。卸载应用会删除本机数据；如需保留副本，请先使用数据导入导出功能。我们使用系统安全机制，并建议你为设备启用密码。", "記錄會保留到你在應用程式中刪除、清除應用程式資料或移除應用程式。移除應用程式會刪除本機資料；如需保留副本，請先使用資料匯入匯出功能。我們使用系統安全機制，並建議你為裝置啟用密碼。", "Records remain until you delete them in the app, clear app data, or uninstall the app. Uninstalling removes local data; use data import and export first if you want to keep a copy. We rely on system security and recommend protecting your device with a passcode.")),
            (value("6. 儿童与医疗信息", "6. 兒童與醫療資訊", "6. Children and health information"), value("BBBuddy 面向照护者使用，不供儿童自行创建账户或直接使用。请确保你有权录入和共享相关宝宝资料。BBBuddy 是家庭记录工具，不提供医疗诊断或紧急服务；健康问题请咨询合格的医疗专业人员。", "BBBuddy 面向照護者使用，不供兒童自行建立帳號或直接使用。請確保你有權輸入和分享相關寶寶資料。BBBuddy 是家庭記錄工具，不提供醫療診斷或緊急服務；健康問題請諮詢合格的醫療專業人員。", "BBBuddy is intended for caregivers, not for children to create accounts or use directly. Make sure you are authorized to enter and share the baby’s information. BBBuddy is a family record-keeping tool, not a medical diagnosis or emergency service; consult a qualified health professional for health concerns.")),
            (value("7. 政策更新与联系", "7. 政策更新與聯絡", "7. Updates and contact"), value("我们可能随功能或法律要求更新本政策，并会在应用内更新生效日期。隐私相关问题可通过 App Store 产品页所列的开发者联系方式联系我们。", "我們可能隨功能或法律要求更新本政策，並會在應用程式內更新生效日期。隱私相關問題可透過 App Store 產品頁所列的開發者聯絡方式與我們聯絡。", "We may update this policy as features or legal requirements change and will update the effective date in the app. For privacy questions, contact us using the developer contact information shown on the App Store product page."))
        ]
    }

    static var termsIntroduction: String { value("使用 BBBuddy 即表示你同意本条款。若你不同意，请停止使用应用。Plus 购买还受 App Store 购买确认页及 Apple 条款约束。", "使用 BBBuddy 即表示你同意本條款。若你不同意，請停止使用應用程式。Plus 購買還受 App Store 購買確認頁及 Apple 條款約束。", "By using BBBuddy, you agree to these terms. If you do not agree, stop using the app. Plus purchases are also governed by the App Store purchase confirmation and Apple’s terms.") }
    static var termsSections: [(title: String, body: String)] {
        [
            (value("1. 服务用途", "1. 服務用途", "1. Purpose of the service"), value("BBBuddy 用于帮助照护者记录宝宝照护、成长与陪伴信息。你应提供真实、合法且有权处理的内容，并妥善保护设备与导出文件。", "BBBuddy 用於協助照護者記錄寶寶照護、成長與陪伴資訊。你應提供真實、合法且有權處理的內容，並妥善保護裝置與匯出檔案。", "BBBuddy helps caregivers record baby care, growth, and companionship information. You are responsible for providing lawful content you are authorized to process and for protecting your device and exported files.")),
            (value("2. Plus 购买与续订", "2. Plus 購買與續訂", "2. Plus purchases and renewal"), value("月付和年付方案由 App Store 自动续订，除非你在当前周期结束前按 Apple 的要求取消；终身方案为一次性购买。实际价格、试用资格、计费周期、税费、退款与续订时间以 App Store 显示为准。你可以在 Apple 账户的订阅设置中管理或取消订阅。", "月付和年付方案由 App Store 自動續訂，除非你在目前週期結束前依 Apple 的要求取消；終身方案為一次性購買。實際價格、試用資格、計費週期、稅費、退款與續訂時間以 App Store 顯示為準。你可以在 Apple 帳號的訂閱設定中管理或取消訂閱。", "Monthly and yearly plans renew automatically through the App Store unless cancelled under Apple’s requirements before the current period ends; lifetime access is a one-time purchase. Prices, trial eligibility, billing periods, taxes, refunds, and renewal timing are those shown by the App Store. Manage or cancel subscriptions in your Apple Account subscription settings.")),
            (value("3. 内容与导出责任", "3. 內容與匯出責任", "3. Content and export responsibility"), value("你应妥善保护宝宝资料和导出文件，只向有权查看这些内容的人提供副本。BBBuddy 无法远程删除你已通过系统分享或其他方式交付给他人的副本。", "你應妥善保護寶寶資料與匯出檔案，只向有權查看這些內容的人提供副本。BBBuddy 無法遠端刪除你已透過系統分享或其他方式交付給他人的副本。", "Protect baby information and exported files, and provide copies only to people authorized to view them. BBBuddy cannot remotely delete copies you have delivered to others through system sharing or other means.")),
            (value("4. 医疗免责声明", "4. 醫療免責聲明", "4. Medical disclaimer"), value("应用中的提醒、趋势、预测、参考标准和自动分析仅用于日常记录与信息整理，不构成医疗建议、诊断或治疗，也不能替代医生判断。发生紧急情况时，请立即联系当地急救服务。", "應用程式中的提醒、趨勢、預測、參考標準和自動分析僅用於日常記錄與資訊整理，不構成醫療建議、診斷或治療，也不能取代醫師判斷。發生緊急情況時，請立即聯絡當地緊急救援服務。", "Reminders, trends, predictions, reference standards, and automated analyses are for everyday record keeping and organization only. They are not medical advice, diagnosis, or treatment and do not replace professional judgment. Contact local emergency services immediately in an emergency.")),
            (value("5. 禁止行为", "5. 禁止行為", "5. Prohibited conduct"), value("你不得利用 BBBuddy 侵犯他人隐私或知识产权、处理违法或恶意内容、干扰应用、绕过付费限制，或将应用用于任何违法用途。", "你不得利用 BBBuddy 侵犯他人隱私或智慧財產權、處理違法或惡意內容、干擾應用程式、繞過付費限制，或將應用程式用於任何違法用途。", "You may not use BBBuddy to violate privacy or intellectual-property rights, process unlawful or malicious content, interfere with the app, bypass payment limits, or for any unlawful purpose.")),
            (value("6. 服务变更与可用性", "6. 服務變更與可用性", "6. Changes and availability"), value("我们会努力保持服务稳定，但不保证所有功能始终无中断或无错误。系统、网络、App Store 或设备限制可能影响部分功能。我们可为安全、合规或产品改进调整功能，但不会因此减少已由 App Store 确认的有效购买期限。", "我們會努力維持服務穩定，但不保證所有功能始終不中斷或沒有錯誤。系統、網路、App Store 或裝置限制可能影響部分功能。我們可基於安全、合規或產品改進調整功能，但不會因此減少已由 App Store 確認的有效購買期限。", "We work to keep the service reliable but do not guarantee uninterrupted or error-free operation. System, network, App Store, or device limits may affect features. We may change features for safety, compliance, or product improvement, but will not shorten a valid purchase period confirmed by the App Store.")),
            (value("7. 知识产权与责任限制", "7. 智慧財產權與責任限制", "7. Intellectual property and limitation of liability"), value("BBBuddy 的软件、设计、品牌与内置内容受相关法律保护；你保留对自己录入内容的权利。在法律允许的最大范围内，BBBuddy 不对因依赖非医疗用途信息、设备故障、第三方服务或未经授权共享造成的间接损失负责。法律不允许排除的消费者权利不受影响。", "BBBuddy 的軟體、設計、品牌與內建內容受相關法律保護；你保留對自己輸入內容的權利。在法律允許的最大範圍內，BBBuddy 不對因依賴非醫療用途資訊、裝置故障、第三方服務或未經授權分享造成的間接損失負責。法律不允許排除的消費者權利不受影響。", "BBBuddy’s software, design, brand, and built-in content are legally protected; you retain rights in content you enter. To the fullest extent permitted by law, BBBuddy is not liable for indirect losses arising from reliance on non-medical information, device failure, third-party services, or unauthorized sharing. Consumer rights that cannot legally be excluded remain unaffected.")),
            (value("8. 条款更新与联系", "8. 條款更新與聯絡", "8. Updates and contact"), value("我们可能更新本条款并在应用内修改生效日期。重大变更生效后继续使用应用，表示你接受更新后的条款。问题可通过 App Store 产品页所列的开发者联系方式联系我们。", "我們可能更新本條款並在應用程式內修改生效日期。重大變更生效後繼續使用應用程式，表示你接受更新後的條款。問題可透過 App Store 產品頁所列的開發者聯絡方式聯絡我們。", "We may update these terms and change the effective date in the app. Continued use after a material update takes effect means you accept the revised terms. For questions, contact us using the developer contact information on the App Store product page."))
        ]
    }
    static var appleStandardTerms: String { value("查看 Apple 标准最终用户许可协议", "查看 Apple 標準終端使用者授權協議", "View Apple’s Standard End User License Agreement") }
}
