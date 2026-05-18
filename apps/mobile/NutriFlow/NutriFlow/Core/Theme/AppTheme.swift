import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.03, green: 0.04, blue: 0.06)
    static let accent = Color.green
    static let primaryButtonText = Color.black
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.5)
    static let textTertiary = Color.white.opacity(0.6)
    static let cardBackground = Color.white.opacity(0.05)
    static let cardBorder = Color.white.opacity(0.06)
    static let fieldBackground = Color.white.opacity(0.04)
    static let fieldBorder = Color.white.opacity(0.06)
    static let error = Color.red.opacity(0.85)
    static let errorBackground = Color.red.opacity(0.08)
    static let logoutBorder = Color.red
    static let logoutBackground = Color.red.opacity(0.1)
    static let headerBackground = Color.black.opacity(0.3)
    static let cornerRadiusSmall: CGFloat = 10
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 14
    static let cornerRadiusTabBar: CGFloat = 20
    static let chipCornerRadius: CGFloat = 20
    static let iconSize: CGFloat = 20
    static let tabBarIconSize: CGFloat = 20
    static let avatarSize: CGFloat = 80
    static let paddingHorizontal: CGFloat = 20
    static let paddingVertical: CGFloat = 12
    static let headerPaddingTop: CGFloat = 60
    static let bottomPadding: CGFloat = 120
    static let buttonHeight: CGFloat = 50
}