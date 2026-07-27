import Foundation
import SwiftUI

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        self.init(
            .sRGB,
            red: Double((number & 0xFF0000) >> 16) / 255,
            green: Double((number & 0x00FF00) >> 8) / 255,
            blue: Double(number & 0x0000FF) / 255,
            opacity: 1
        )
    }
}
