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

    static func registerFonts() {
        // The font is registered automatically through UIAppFonts in Info.plist.
    }

    static func font(size: CGFloat, weight: BBBFontWeight = .regular, bevel: CGFloat = 100) -> Font {
        Font(uiFont(size: size, weight: weight, bevel: bevel))
    }

    /// Opt-in Dynamic Type support for screens that have completed adaptive
    /// layout validation. Existing call sites intentionally keep their current
    /// sizing until they are migrated and tested.
    static func scaledFont(
        size: CGFloat,
        weight: BBBFontWeight = .regular,
        bevel: CGFloat = 100,
        relativeTo textStyle: UIFont.TextStyle = .body,
        maximumPointSize: CGFloat? = nil
    ) -> Font {
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        let baseFont = uiFont(size: size, weight: weight, bevel: bevel)
        let scaled: UIFont
        if let maximumPointSize {
            scaled = metrics.scaledFont(for: baseFont, maximumPointSize: maximumPointSize)
        } else {
            scaled = metrics.scaledFont(for: baseFont)
        }
        return Font(scaled)
    }

    static func uiFont(size: CGFloat, weight: BBBFontWeight = .regular, bevel: CGFloat = 100) -> UIFont {
        registerFonts()

        let safeWeight = CGFloat(clamped(weight.value, min: 200, max: 700))
        let safeBevel = CGFloat(clamped(bevel, min: 1, max: 100))

        // Create base CTFont from registered custom font name
        guard let ctFont = CTFontCreateWithName(postScriptName as CFString, size, nil) as CTFont? else {
            return UIFont.systemFont(ofSize: size, weight: weight.systemWeight)
        }

        // Four-char variation axis identifiers extracted from font binary:
        // wght = 0x77676874, BEVL = 0x4245564C
        let variationAxisWght = NSNumber(value: Int32(bitPattern: 0x77676874))
        let variationAxisBevL = NSNumber(value: Int32(bitPattern: 0x4245564C))

        // CTFontDescriptorCreateCopyWithVariation accepts ONE axis identifier + value per call.
        // Chain: apply wght first, then BEVL on top of the result.
        let fontDescriptor = CTFontCopyFontDescriptor(ctFont)

        guard let withWght = CTFontDescriptorCreateCopyWithVariation(fontDescriptor, variationAxisWght, safeWeight) as CTFontDescriptor? else {
            return UIFont.systemFont(ofSize: size, weight: weight.systemWeight)
        }

        guard let variedDescriptor = CTFontDescriptorCreateCopyWithVariation(withWght, variationAxisBevL, safeBevel) as CTFontDescriptor? else {
            return UIFont.systemFont(ofSize: size, weight: weight.systemWeight)
        }

        let variedFont = CTFontCreateWithFontDescriptor(variedDescriptor, size, nil)
        return variedFont as UIFont
    }

    private static func clamped(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
