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

    // MARK: - Color Tokens
    public static let cardMaterial: Material = .ultraThinMaterial
    public static let cardGlass: Material = .ultraThinMaterial
    public static let cardSolid = Color(red: 0.08, green: 0.16, blue: 0.32)
    public static let cardBorder = Color.white.opacity(0.18)
    public static let cardBorderLight = Color.white.opacity(0.10)

    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.80)
    public static let textTertiary = Color.white.opacity(0.60)
    public static let separator = Color.white.opacity(0.16)
    public static let iconTint = Color.white.opacity(0.90)

    public static let accent = Color(red: 0.18, green: 0.52, blue: 0.98)
    public static let alertAmber = Color(red: 0.96, green: 0.65, blue: 0.14)
    public static let rainBlue = Color(red: 0.35, green: 0.65, blue: 1.0)
    public static let rainBlueLight = Color(red: 0.55, green: 0.85, blue: 1.0)

    // MARK: - Spacing Tokens
    public static let spacingXXSmall: CGFloat = 4
    public static let spacingXSmall: CGFloat = 6
    public static let spacingSmall: CGFloat = 8
    public static let spacingMedium: CGFloat = 12
    public static let spacingLarge: CGFloat = 16
    public static let spacingXLarge: CGFloat = 20
    public static let spacingXXLarge: CGFloat = 24
    public static let spacingCardPadding: CGFloat = 16
    public static let tabBarClearance: CGFloat = 88.0

    // MARK: - Corner Radius Tokens
    public static let radiusSmall: CGFloat = 8
    public static let radiusMedium: CGFloat = 12
    public static let radiusCard: CGFloat = 16
    public static let radiusLarge: CGFloat = 20
}

// MARK: - Dynamic Type Font Tokens

public enum AppFont {
    // Big Hero Temperature & Display
    public static var heroTemperature: Font {
        Font.system(.largeTitle, design: .rounded, weight: .thin)
    }

    // Titles
    public static var largeTitle: Font {
        Font.system(.largeTitle, design: .default, weight: .bold)
    }
    public static var title: Font {
        Font.system(.title, design: .default, weight: .bold)
    }
    public static var title2: Font {
        Font.system(.title2, design: .default, weight: .semibold)
    }
    public static var title2Bold: Font {
        Font.system(.title2, design: .default, weight: .bold)
    }
    public static var title3: Font {
        Font.system(.title3, design: .default, weight: .semibold)
    }
    public static var title3Bold: Font {
        Font.system(.title3, design: .default, weight: .bold)
    }

    // Headline & Body
    public static var headline: Font {
        Font.system(.headline, design: .default, weight: .semibold)
    }
    public static var body: Font {
        Font.system(.body, design: .default, weight: .regular)
    }
    public static var bodySemibold: Font {
        Font.system(.body, design: .default, weight: .semibold)
    }
    public static var bodyMedium: Font {
        Font.system(.body, design: .default, weight: .medium)
    }

    // Callout & Subheadline
    public static var callout: Font {
        Font.system(.callout, design: .default, weight: .regular)
    }
    public static var calloutMedium: Font {
        Font.system(.callout, design: .default, weight: .medium)
    }
    public static var calloutSemibold: Font {
        Font.system(.callout, design: .default, weight: .semibold)
    }
    public static var subheadline: Font {
        Font.system(.subheadline, design: .default, weight: .regular)
    }
    public static var subheadlineMedium: Font {
        Font.system(.subheadline, design: .default, weight: .medium)
    }
    public static var subheadlineSemibold: Font {
        Font.system(.subheadline, design: .default, weight: .semibold)
    }

    // Footnote & Caption
    public static var footnote: Font {
        Font.system(.footnote, design: .default, weight: .regular)
    }
    public static var footnoteMedium: Font {
        Font.system(.footnote, design: .default, weight: .medium)
    }
    public static var footnoteSemibold: Font {
        Font.system(.footnote, design: .default, weight: .semibold)
    }
    public static var caption: Font {
        Font.system(.caption, design: .default, weight: .regular)
    }
    public static var captionMedium: Font {
        Font.system(.caption, design: .default, weight: .medium)
    }
    public static var captionSemibold: Font {
        Font.system(.caption, design: .default, weight: .semibold)
    }
    public static var caption2: Font {
        Font.system(.caption2, design: .default, weight: .regular)
    }
    public static var caption2Medium: Font {
        Font.system(.caption2, design: .default, weight: .medium)
    }
    public static var caption2Semibold: Font {
        Font.system(.caption2, design: .default, weight: .semibold)
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
            .font(.system(size: fontSize, weight: .thin, design: .rounded))
            .tracking(-2)
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
        content
            .padding(padding)
            .background(
                Group {
                    if reduceTransparency {
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
                    .stroke(borderColor ?? AppTheme.cardBorder, lineWidth: 0.8)
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
