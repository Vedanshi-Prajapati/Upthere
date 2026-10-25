import SwiftUI

enum AppTheme {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.42, blue: 0.82),
            Color(red: 0.05, green: 0.19, blue: 0.50)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Color Tokens (WCAG AA Certified)
    static let cardMaterial: Material = .ultraThinMaterial
    static let cardGlass: Material = .ultraThinMaterial
    static let cardSolid = Color(red: 0.08, green: 0.16, blue: 0.32)
    static let cardBorder = Color.white.opacity(0.24)
    static let cardBorderLight = Color.white.opacity(0.14)
    static let cardBorderHighContrast = Color.white.opacity(0.70)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.86)
    static let textTertiary = Color.white.opacity(0.72)
    static let separator = Color.white.opacity(0.22)
    static let iconTint = Color.white.opacity(0.92)

    static let accent = Color(red: 0.42, green: 0.74, blue: 1.0)
    static let alertAmber = Color(red: 1.0, green: 0.76, blue: 0.24)
    static let rainBlue = Color(red: 0.46, green: 0.76, blue: 1.0)
    static let rainBlueLight = Color(red: 0.65, green: 0.88, blue: 1.0)

    // MARK: - Chart Contrast Tokens (>= 3.0:1 against cards)
    static let chartLine = Color.white
    static let chartGrid = Color.white.opacity(0.44)
    static let chartGridLow = Color.white.opacity(0.38)
    static let chartAxisLabel = Color.white.opacity(0.86)
    static let chartSelectedPoint = Color.white

    // MARK: - Contrast Helpers
    static func textSecondary(for contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? .white : textSecondary
    }

    static func textTertiary(for contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color.white.opacity(0.96) : textTertiary
    }

    // MARK: - Spacing Tokens
    static let spacingXXSmall: CGFloat = 4
    static let spacingXSmall: CGFloat = 6
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 12
    static let spacingLarge: CGFloat = 16
    static let spacingXLarge: CGFloat = 20
    static let spacingXXLarge: CGFloat = 28
    static let sectionGap: CGFloat = 28
    static let cardInnerGap: CGFloat = 12
    static let screenHorizontalMargin: CGFloat = 20
    static let spacingCardPadding: CGFloat = 16
    static let tabBarClearance: CGFloat = 88.0

    // MARK: - Corner Radius Tokens
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusCard: CGFloat = 16
    static let radiusLarge: CGFloat = 20
}

// MARK: - Five-Role Type Scale

enum AppTypeRole {
    case hero      // Dominant Hero (temperature)
    case title     // Screen / section headers
    case headline  // Card title / key value
    case body      // General body text
    case caption   // Details, metadata, feels-like, high/low, timestamps
}

enum AppFont {
    // 1. Hero (temperature): dominant, rounded, bold
    static var hero: Font {
        Font.system(.largeTitle, design: .rounded, weight: .bold)
    }

    // 2. Title (screen / section): large, distinct section anchor
    static var title: Font {
        Font.system(.title2, design: .default, weight: .bold)
    }

    // 3. Headline (card title / key value): semibold card focus
    static var headline: Font {
        Font.system(.headline, design: .default, weight: .semibold)
    }

    // 4. Body: standard reading text
    static var body: Font {
        Font.system(.body, design: .default, weight: .regular)
    }

    // 5. Caption: secondary detail, metadata, footnotes
    static var caption: Font {
        Font.system(.caption, design: .default, weight: .regular)
    }

    static func role(_ role: AppTypeRole) -> Font {
        switch role {
        case .hero: return hero
        case .title: return title
        case .headline: return headline
        case .body: return body
        case .caption: return caption
        }
    }

    // Backwards-compatible aliases mapping all legacy calls strictly into the 5 roles:
    static var heroTemperature: Font { hero }
    static var largeTitle: Font { title }
    static var title2: Font { title }
    static var title2Bold: Font { title }
    static var title3: Font { title }
    static var title3Bold: Font { title }

    static var bodySemibold: Font { body.weight(.semibold) }
    static var bodyMedium: Font { body.weight(.medium) }
    static var callout: Font { body }
    static var calloutMedium: Font { body.weight(.medium) }
    static var calloutSemibold: Font { headline }

    static var subheadline: Font { caption }
    static var subheadlineMedium: Font { caption.weight(.medium) }
    static var subheadlineSemibold: Font { headline }

    static var footnote: Font { caption }
    static var footnoteMedium: Font { caption.weight(.medium) }
    static var footnoteSemibold: Font { caption.weight(.semibold) }

    static var captionMedium: Font { caption.weight(.medium) }
    static var captionSemibold: Font { caption.weight(.semibold) }
    static var caption2: Font { caption }
    static var caption2Medium: Font { caption.weight(.medium) }
    static var caption2Semibold: Font { caption.weight(.semibold) }
}

extension View {
    func appType(_ role: AppTypeRole) -> some View {
        self.font(AppFont.role(role))
    }
}

// MARK: - Scaled Metric Tokens & View Wrappers

enum AppMetrics {
    static let baseHeroTemperatureSize: CGFloat = 88
    static let baseWeatherIconSize: CGFloat = 28
    static let baseCityRowIconSize: CGFloat = 22
}

struct ScaledHeroTemperature: View {
    @Environment(\.weatherFormatter) private var weatherFormatter
    let temperature: Double
    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = AppMetrics.baseHeroTemperatureSize

    init(_ temperature: Double) {
        self.temperature = temperature
    }

    var body: some View {
        Text(weatherFormatter.temp(temperature))
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .tracking(-2)
            .foregroundStyle(AppTheme.textPrimary)
            .accessibilityLabel(Text("\(weatherFormatter.tempWithUnit(temperature))"))
    }
}

struct ScaledWeatherIcon: View {
    let symbolName: String
    var relativeTo: Font.TextStyle = .title2
    var baseSize: CGFloat = AppMetrics.baseWeatherIconSize
    @ScaledMetric private var iconSize: CGFloat

    init(symbolName: String, relativeTo: Font.TextStyle = .title2, baseSize: CGFloat = AppMetrics.baseWeatherIconSize) {
        self.symbolName = symbolName
        self.relativeTo = relativeTo
        self.baseSize = baseSize
        self._iconSize = ScaledMetric(wrappedValue: baseSize, relativeTo: relativeTo)
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: iconSize))
    }
}

// MARK: - WeatherCard

struct WeatherCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    var cornerRadius: CGFloat
    var padding: EdgeInsets
    var borderColor: Color?
    var content: Content

    init(
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

    init(
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

    var body: some View {
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
    func weatherCard(
        cornerRadius: CGFloat = AppTheme.radiusCard,
        padding: CGFloat = AppTheme.spacingCardPadding,
        borderColor: Color? = nil
    ) -> some View {
        WeatherCard(cornerRadius: cornerRadius, padding: padding, borderColor: borderColor) {
            self
        }
    }
}
