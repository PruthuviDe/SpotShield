import SwiftUI

public enum AppTypography {
    // Screen and section titles
    public static let titleLarge = Font.system(.largeTitle, design: .default, weight: .bold)
    public static let titleMedium = Font.system(.title2, design: .default, weight: .semibold)
    public static let titleSmall = Font.system(.headline, design: .default, weight: .semibold)

    // Body text
    public static let bodyMedium = Font.system(.body, design: .default, weight: .regular)
    public static let bodySmall = Font.system(.callout, design: .default, weight: .regular)
    public static let bodyBold = Font.system(.body, design: .default, weight: .semibold)

    // Secondary text and badge labels
    public static let caption = Font.system(.caption, design: .default, weight: .regular)
    public static let captionBold = Font.system(.caption, design: .default, weight: .semibold)

    // Monospaced text-style fonts that scale with Dynamic Type
    public static let timerDisplay = Font.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit()
    public static let priceDisplay = Font.system(.title3, design: .default, weight: .bold).monospacedDigit()
}
