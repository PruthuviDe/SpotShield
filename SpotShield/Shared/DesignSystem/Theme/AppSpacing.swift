import SwiftUI

public enum AppSpacing {
    // 4-point spacing scale with an 8-point rhythm
    public static let xxSmall: CGFloat = 4
    public static let xSmall: CGFloat = 8
    public static let small: CGFloat = 12
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 24
    public static let xLarge: CGFloat = 32
    public static let xxLarge: CGFloat = 48

    // Corner radius tokens
    public static let radiusSmall: CGFloat = 8
    public static let radiusButton: CGFloat = 12
    public static let radiusCard: CGFloat = 16
    public static let radiusPill: CGFloat = 999

    // Minimum touch target size for accessibility
    public static let minTouchTarget: CGFloat = 44
}
