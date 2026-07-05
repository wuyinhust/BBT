import Foundation

enum AppVariant {
    #if APPSTORE_REVIEW
    static let isAppStoreReview = true
    #else
    static let isAppStoreReview = false
    #endif

    static var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "版本 \(version) (\(build))"
    }

    static var profileVersionText: String {
        isAppStoreReview ? versionText : "测试版 · \(versionText)"
    }

    #if LOCAL_DEBUG_UNLOCKS
    static let unlocksAllBuddiesForLocalRun = true
    #else
    static let unlocksAllBuddiesForLocalRun = false
    #endif
}
