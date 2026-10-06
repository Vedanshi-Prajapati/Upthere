import SwiftUI

public enum AppTheme {
    // MARK: - Background
    public static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.42, blue: 0.82),
            Color(red: 0.05, green: 0.19, blue: 0.50)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Glass Cards
    public static let cardGlass = Color.white.opacity(0.11)
    public static let cardBorder = Color.white.opacity(0.18)

    // MARK: - Text
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.65)
    public static let textTertiary = Color.white.opacity(0.45)

    // MARK: - Tab Bar
    public static let tabBarBackground = Color(red: 0.07, green: 0.20, blue: 0.52)
    public static let tabBarSelectedPill = Color.white.opacity(0.14)

    // MARK: - Accent
    public static let accent = Color(red: 0.18, green: 0.52, blue: 0.98)
    public static let alertAmber = Color(red: 0.96, green: 0.65, blue: 0.14)
}
