import XCTest

final class BBBUILocalizationScreenshotTests: XCTestCase {
    private let screens = [
        "settings",
        "basic-home",
        "easy-home",
        "buddy",
        "onboarding-mode",
        "growth-weight",
        "feeding"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Run this test with BB_UI_LANGUAGE and BB_UI_CONTENT_SIZE_CATEGORY to
    /// produce a deterministic screenshot matrix without shipping test routes
    /// in Release builds.
    func testLocalizedTargetScreens() throws {
        let environment = ProcessInfo.processInfo.environment
        let language = environment["BB_UI_LANGUAGE"] ?? "en"
        let contentSize = environment["BB_UI_CONTENT_SIZE_CATEGORY"]
            ?? "UICTContentSizeCategoryL"

        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = [
                "-AppleLanguages", "(\(language))",
                "-AppleLocale", localeIdentifier(for: language),
                "-UIPreferredContentSizeCategoryName", contentSize,
                "-BBUITestScreen", screen,
                "-BBUIUnitSystem", "imperial"
            ]
            if screen == "onboarding-mode" {
                app.launchArguments.append("-BBUIOnboardingModePage")
            }

            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 12))
            sleep(1)

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "\(language)-\(contentSize)-\(screen)"
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
        }
    }

    private func localeIdentifier(for language: String) -> String {
        switch language {
        case "zh-Hans": return "zh_CN"
        case "zh-Hant": return "zh_TW"
        default: return "en_US"
        }
    }
}
