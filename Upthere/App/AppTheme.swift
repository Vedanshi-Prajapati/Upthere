import SwiftUI

public enum AppTheme {
    public static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.42, blue: 0.82),
            Color(red: 0.05, green: 0.19, blue: 0.50)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Color Tokens (WCAG AA Certified)
    public static let cardMaterial: Material = .ultraThinMaterial
    public static let cardGlass: Material = .ultraThinMaterial
    public static let cardSolid = Color(red: 0.08, green: 0.16, blue: 0.32)
    public static let cardBorder = Color.white.opacity(0.24)
    public static let cardBorderLight = Color.white.opacity(0.14)
    public static let cardBorderHighContrast = Color.white.opacity(0.70)

    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.86)
    public static let textTertiary = Color.white.opacity(0.72)
    public static let separator = Color.white.opacity(0.22)
    public static let iconTint = Color.white.opacity(0.92)

    public static let accent = Color(red: 0.42, green: 0.74, blue: 1.0)
    public static let alertAmber = Color(red: 1.0, green: 0.76, blue: 0.24)
    public static let rainBlue = Color(red: 0.46, green: 0.76, blue: 1.0)
    public static let rainBlueLight = Color(red: 0.65, green: 0.88, blue: 1.0)

    // MARK: - Chart Contrast Tokens (>= 3.0:1 against cards)
    public static let chartLine = Color.white
    public static let chartGrid = Color.white.opacity(0.44)
    public static let chartGridLow = Color.white.opacity(0.38)
    public static let chartAxisLabel = Color.white.opacity(0.86)
    public static let chartSelectedPoint = Color.white

    // MARK: - Contrast Helpers
    public static func textSecondary(for contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? .white : textSecondary
    }

    public static func textTertiary(for contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color.white.opacity(0.96) : textTertiary
    }

    // MARK: - Spacing Tokens
    public static let spacingXXSmall: CGFloat = 4
    public static let spacingXSmall: CGFloat = 6
    public static let spacingSmall: CGFloat = 8
    public static let spacingMedium: CGFloat = 12
    public static let spacingLarge: CGFloat = 16
    public static let spacingXLarge: CGFloat = 20
    public static let spacingXXLarge: CGFloat = 28
    public static let sectionGap: CGFloat = 28
    public static let cardInnerGap: CGFloat = 12
    public static let screenHorizontalMargin: CGFloat = 20
    public static let spacingCardPadding: CGFloat = 16
    public static let tabBarClearance: CGFloat = 88.0

    // MARK: - Corner Radius Tokens
    public static let radiusSmall: CGFloat = 8
    public static let radiusMedium: CGFloat = 12
    public static let radiusCard: CGFloat = 16
    public static let radiusLarge: CGFloat = 20
}

// MARK: - Five-Role Type Scale

public enum AppTypeRole {
    case hero      // Dominant Hero (temperature)
    case title     // Screen / section headers
    case headline  // Card title / key value
    case body      // General body text
    case caption   // Details, metadata, feels-like, high/low, timestamps
}

public enum AppFont {
    // 1. Hero (temperature): dominant, rounded, bold
    public static var hero: Font {
        Font.system(.largeTitle, design: .rounded, weight: .bold)
    }

    // 2. Title (screen / section): large, distinct section anchor
    public static var title: Font {
        Font.system(.title2, design: .default, weight: .bold)
    }

    // 3. Headline (card title / key value): semibold card focus
    public static var headline: Font {
        Font.system(.headline, design: .default, weight: .semibold)
    }

    // 4. Body: standard reading text
    public static var body: Font {
        Font.system(.body, design: .default, weight: .regular)
    }

    // 5. Caption: secondary detail, metadata, footnotes
    public static var caption: Font {
        Font.system(.caption, design: .default, weight: .regular)
    }

    public static func role(_ role: AppTypeRole) -> Font {
        switch role {
        case .hero: return hero
        case .title: return title
        case .headline: return headline
        case .body: return body
        case .caption: return caption
        }
    }

    // Backwards-compatible aliases mapping all legacy calls strictly into the 5 roles:
    public static var heroTemperature: Font { hero }
    public static var largeTitle: Font { title }
    public static var title2: Font { title }
    public static var title2Bold: Font { title }
    public static var title3: Font { title }
    public static var title3Bold: Font { title }

    public static var bodySemibold: Font { body.weight(.semibold) }
    public static var bodyMedium: Font { body.weight(.medium) }
    public static var callout: Font { body }
    public static var calloutMedium: Font { body.weight(.medium) }
    public static var calloutSemibold: Font { headline }

    public static var subheadline: Font { caption }
    public static var subheadlineMedium: Font { caption.weight(.medium) }
    public static var subheadlineSemibold: Font { headline }

    public static var footnote: Font { caption }
    public static var footnoteMedium: Font { caption.weight(.medium) }
    public static var footnoteSemibold: Font { caption.weight(.semibold) }

    public static var captionMedium: Font { caption.weight(.medium) }
    public static var captionSemibold: Font { caption.weight(.semibold) }
    public static var caption2: Font { caption }
    public static var caption2Medium: Font { caption.weight(.medium) }
    public static var caption2Semibold: Font { caption.weight(.semibold) }
}

extension View {
    public func appType(_ role: AppTypeRole) -> some View {
        self.font(AppFont.role(role))
    }
}

// MARK: - Scaled Metric Tokens & View Wrappers

public enum AppMetrics {
    public static let baseHeroTemperatureSize: CGFloat = 88
    public static let baseWeatherIconSize: CGFloat = 28
    public static let baseCityRowIconSize: CGFloat = 22
}

public struct ScaledHeroTemperature: View {
    @Environment(\.weatherFormatter) private var weatherFormatter
    let temperature: Double
    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = AppMetrics.baseHeroTemperatureSize

    public init(_ temperature: Double) {
        self.temperature = temperature
    }

    public var body: some View {
        Text(weatherFormatter.temp(temperature))
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .tracking(-2)
            .foregroundStyle(AppTheme.textPrimary)
            .accessibilityLabel(Text("\(weatherFormatter.tempWithUnit(temperature))"))
    }
}

public struct ScaledWeatherIcon: View {
    let symbolName: String
    var relativeTo: Font.TextStyle = .title2
    var baseSize: CGFloat = AppMetrics.baseWeatherIconSize
    @ScaledMetric private var iconSize: CGFloat

    public init(symbolName: String, relativeTo: Font.TextStyle = .title2, baseSize: CGFloat = AppMetrics.baseWeatherIconSize) {
        self.symbolName = symbolName
        self.relativeTo = relativeTo
        self.baseSize = baseSize
        self._iconSize = ScaledMetric(wrappedValue: baseSize, relativeTo: relativeTo)
    }

    public var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: iconSize))
    }
}

// MARK: - WeatherCard

public struct WeatherCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    public var cornerRadius: CGFloat
    public var padding: EdgeInsets
    public var borderColor: Color?
    public var content: Content

    public init(
        cornerRadius: CGFloat = AppTheme.radiusCard,
        padding: EdgeInsets = EdgeInsets(
            top: AppTheme.spacingCardPadding,
            leading: AppTheme.spacingCardPadding,
            bottom: AppTheme.spacingCardPadding,
            trailing: AppTheme.spacingCardPadding
        ),
        borderColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.borderColor = borderColor
        self.content = content()
    }

    public init(
        cornerRadius: CGFloat = AppTheme.radiusCard,
        padding: CGFloat,
        borderColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding)
        self.borderColor = borderColor
        self.content = content()
    }

    public var body: some View {
        let isHighContrast = (colorSchemeContrast == .increased)
        content
            .padding(padding)
            .background(
                Group {
                    if reduceTransparency || isHighContrast {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppTheme.cardSolid)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppTheme.cardGlass)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isHighContrast
                            ? AppTheme.cardBorderHighContrast
                            : (borderColor ?? AppTheme.cardBorder),
                        lineWidth: isHighContrast ? 1.6 : 0.8
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    public func weatherCard(
        cornerRadius: CGFloat = AppTheme.radiusCard,
        padding: CGFloat = AppTheme.spacingCardPadding,
        borderColor: Color? = nil
    ) -> some View {
        WeatherCard(cornerRadius: cornerRadius, padding: padding, borderColor: borderColor) {
            self
        }
    }
}
