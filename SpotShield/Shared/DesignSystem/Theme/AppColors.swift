import SwiftUI
import UIKit

public enum AppColors {

    public static let background = adaptive(
        light: 0xEFF0EF,
        dark: 0x171915
    )

    public static let card = adaptive(
        light: 0xFFFFFF,
        dark: 0x232620
    )

    public static let border = adaptive(
        light: 0xE2E4DE,
        dark: 0x3A3D36
    )

    public static let accent = Color(
        uiColor: UIColor(hex: 0xD7EE46)
    )

    public static let accentPressed = Color(
        uiColor: UIColor(hex: 0xC5DB3F)
    )

    public static let accentBackground = adaptive(
        light: 0xF3F8D6,
        dark: 0x30371B
    )

    public static let buttonBackground = adaptive(
        light: 0x30312F,
        dark: 0x353830
    )

    public static let textPrimary = adaptive(
        light: 0x060606,
        dark: 0xEFF0EF
    )

    public static let textSecondary = adaptive(
        light: 0x5F6672,
        dark: 0xA3A99E
    )

    public static let textOnAccent = Color(
        uiColor: UIColor(hex: 0x060606)
    )

    // Always white for dark containers
    public static let textLight = Color(
        uiColor: UIColor(hex: 0xFFFFFF)
    )

    public static let statusValid = adaptive(
        light: 0x166534,
        dark: 0x86EFAC
    )

    public static let statusValidBackground = adaptive(
        light: 0xE6F7ED,
        dark: 0x123524
    )

    public static let statusExpiring = adaptive(
        light: 0x92400E,
        dark: 0xFCD34D
    )

    public static let statusExpiringBackground = adaptive(
        light: 0xFEF3C7,
        dark: 0x3B2A12
    )

    public static let statusOverstay = adaptive(
        light: 0xB91C1C,
        dark: 0xFCA5A5
    )

    public static let statusOverstayBackground = adaptive(
        light: 0xFEE2E2,
        dark: 0x3F1D1D
    )

    public static let statusNeutral = adaptive(
        light: 0x4B5563,
        dark: 0xD1D5DB
    )

    public static let statusNeutralBackground = adaptive(
        light: 0xF3F4F6,
        dark: 0x272A25
    )

    private static func adaptive(
        light: UInt32,
        dark: UInt32
    ) -> Color {
        Color(
            uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark
                    ? dark
                    : light

                return UIColor(hex: hex)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
