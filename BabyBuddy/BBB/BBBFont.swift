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
        case .regular:
            return 400
        case .medium:
            return 500
        case .semibold:
            return 600
        case .bold:
            return 660
        case .heavy:
            return 700
        }
    }
}

enum BBBFont {
    static let fileName = "AlimamaFangYuanTiVF-Thin.ttf"
    static let postScriptName = "AlimamaFangYuanTiVF-Thin"

    private static let weightAxis = axisID("wght")
    private static let bevelAxis = axisID("BEVL")
    private static var didRegister = false

    static func registerFonts() {
        guard !didRegister,
              let url = Bundle.main.url(forResource: "AlimamaFangYuanTiVF-Thin", withExtension: "ttf") else {
            return
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        didRegister = true
    }

    static func font(size: CGFloat, weight: BBBFontWeight = .regular, bevel: CGFloat = 100) -> Font {
        Font(uiFont(size: size, weight: weight, bevel: bevel))
    }

    static func uiFont(size: CGFloat, weight: BBBFontWeight = .regular, bevel: CGFloat = 100) -> UIFont {
        registerFonts()

        let variations: [NSNumber: NSNumber] = [
            NSNumber(value: weightAxis): NSNumber(value: Double(clamped(weight.value, min: 200, max: 700))),
            NSNumber(value: bevelAxis): NSNumber(value: Double(clamped(bevel, min: 1, max: 100)))
        ]
        let descriptor = UIFontDescriptor(name: postScriptName, size: size)
            .addingAttributes([UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations])
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func clamped(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    private static func axisID(_ tag: String) -> Int {
        tag.utf8.reduce(0) { result, byte in
            (result << 8) + Int(byte)
        }
    }
}
