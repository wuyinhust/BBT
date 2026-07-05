import SwiftUI
import UIKit
import CoreText

enum BBBFontWeight {
    case regular
    case medium
    case semibold
    case bold
    case heavy

    var value: CGFloat {
        switch self {
        case .regular: return 400
        case .medium: return 500
        case .semibold: return 600
        case .bold: return 660
        case .heavy: return 700
        }
    }

    var systemWeight: UIFont.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        }
    }
}

enum BBBFont {
    static let postScriptName = "AlimamaFangYuanTiVF-Thin"

    private static var didRegister = false

    static func registerFonts() {
        guard !didRegister else { return }
        // Font is registered via UIAppFonts in Info.plist — no manual registration needed.
        // This function is kept for explicit registration calls but is a no-op.
        // UIFont(name:) will work if UIAppFonts successfully loaded the font.
        didRegister = true
        NSLog("[BBBFont] Font registration check complete (relies on UIAppFonts in Info.plist)")
    }

    static func font(size: CGFloat, weight: BBBFontWeight = .regular, bevel: CGFloat = 100) -> Font {
        Font(uiFont(size: size, weight: weight, bevel: bevel))
    }

    static func uiFont(size: CGFloat, weight: BBBFontWeight = .regular, bevel: CGFloat = 100) -> UIFont {
        registerFonts()

        let safeWeight = CGFloat(clamped(weight.value, min: 200, max: 700))
        let safeBevel = CGFloat(clamped(bevel, min: 1, max: 100))

        // Create base CTFont from registered custom font name
        guard let ctFont = CTFontCreateWithName(postScriptName as CFString, size, nil) as CTFont? else {
            NSLog("[BBBFont] ⚠️ Custom font '\(postScriptName)' not available, falling back to system font")
            return UIFont.systemFont(ofSize: size, weight: weight.systemWeight)
        }

        // Four-char variation axis identifiers extracted from font binary:
        // wght = 0x77676874, BEVL = 0x4245564C
        let variationAxisWght = CFNumberCreate(nil, .sInt32Type, [0x77676874] as [Int32])!
        let variationAxisBevL = CFNumberCreate(nil, .sInt32Type, [0x4245564C] as [Int32])!

        // CTFontDescriptorCreateCopyWithVariation accepts ONE axis identifier + value per call.
        // Chain: apply wght first, then BEVL on top of the result.
        let fontDescriptor = CTFontCopyFontDescriptor(ctFont)

        guard let withWght = CTFontDescriptorCreateCopyWithVariation(fontDescriptor, variationAxisWght, safeWeight) as CTFontDescriptor? else {
            NSLog("[BBBFont] ⚠️ wght variation failed, falling back to system font")
            return UIFont.systemFont(ofSize: size, weight: weight.systemWeight)
        }

        guard let variedDescriptor = CTFontDescriptorCreateCopyWithVariation(withWght, variationAxisBevL, safeBevel) as CTFontDescriptor? else {
            NSLog("[BBBFont] ⚠️ BEVL variation failed, falling back to system font")
            return UIFont.systemFont(ofSize: size, weight: weight.systemWeight)
        }

        let variedFont = CTFontCreateWithFontDescriptor(variedDescriptor, size, nil)
        return variedFont as UIFont
    }

    private static func clamped(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
