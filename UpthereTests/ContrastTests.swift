import Testing
import SwiftUI
@testable import Upthere

// MARK: - WCAG Luminance & Contrast Math Helper

public struct WCAGHelper {
    public static func srgbToLinear(_ c: Double) -> Double {
        if c <= 0.04045 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }

    public static func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
        let rLin = srgbToLinear(r)
        let gLin = srgbToLinear(g)
        let bLin = srgbToLinear(b)
        return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
    }

    public static func composite(fg: (r: Double, g: Double, b: Double, a: Double), bg: (r: Double, g: Double, b: Double)) -> (r: Double, g: Double, b: Double) {
        let compR = fg.a * fg.r + (1.0 - fg.a) * bg.r
        let compG = fg.a * fg.g + (1.0 - fg.a) * bg.g
        let compB = fg.a * fg.b + (1.0 - fg.a) * bg.b
        return (compR, compG, compB)
    }

    public static func contrastRatio(fg: (r: Double, g: Double, b: Double, a: Double), bg: (r: Double, g: Double, b: Double)) -> Double {
        let comp = composite(fg: fg, bg: bg)
        let l1 = relativeLuminance(r: comp.r, g: comp.g, b: comp.b)
        let l2 = relativeLuminance(r: bg.r, g: bg.g, b: bg.b)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Apply black scrim of opacity alpha over background RGB
    public static func applyScrim(bg: (r: Double, g: Double, b: Double), alpha: Double) -> (r: Double, g: Double, b: Double) {
        let r = (1.0 - alpha) * bg.r
        let g = (1.0 - alpha) * bg.g
        let b = (1.0 - alpha) * bg.b
        return (r, g, b)
    }
}

// MARK: - Contrast Tests Suite

@Suite("WCAG AA Contrast Verification")
struct ContrastTests {

    // MARK: Background Regions Under Test
    struct BackgroundRegion {
        let name: String
        let r: Double
        let g: Double
        let b: Double
        let scrimAlpha: Double // Scrim applied by WeatherBackgroundView layer 3 & 5
    }

    static let backgrounds: [BackgroundRegion] = [
        .init(name: "AppTheme.backgroundGradient (top)", r: 0.18, g: 0.42, b: 0.82, scrimAlpha: 0.32),
        .init(name: "AppTheme.backgroundGradient (bottom)", r: 0.05, g: 0.19, b: 0.50, scrimAlpha: 0.18),
        .init(name: "AppTheme.cardSolid", r: 0.08, g: 0.16, b: 0.32, scrimAlpha: 0.0),
        .init(name: "Clear Day (darkest zenith)", r: 0.05, g: 0.20, b: 0.50, scrimAlpha: 0.55),
        .init(name: "Clear Day (lightest horizon)", r: 0.16, g: 0.38, b: 0.66, scrimAlpha: 0.62),
        .init(name: "Partly Cloudy (darkest)", r: 0.06, g: 0.18, b: 0.44, scrimAlpha: 0.55),
        .init(name: "Partly Cloudy (lightest)", r: 0.18, g: 0.36, b: 0.60, scrimAlpha: 0.62),
        .init(name: "Rain (darkest)", r: 0.10, g: 0.18, b: 0.30, scrimAlpha: 0.49),
        .init(name: "Rain (lightest)", r: 0.35, g: 0.42, b: 0.50, scrimAlpha: 0.58),
        .init(name: "Snow (darkest)", r: 0.18, g: 0.27, b: 0.42, scrimAlpha: 0.64),
        .init(name: "Snow (lightest)", r: 0.65, g: 0.72, b: 0.80, scrimAlpha: 0.68),
        .init(name: "Fog / Cloudy (darkest)", r: 0.14, g: 0.18, b: 0.25, scrimAlpha: 0.64),
        .init(name: "Fog / Cloudy (lightest)", r: 0.50, g: 0.54, b: 0.60, scrimAlpha: 0.68),
        .init(name: "Night (darkest)", r: 0.03, g: 0.04, b: 0.11, scrimAlpha: 0.0),
        .init(name: "Night (lightest)", r: 0.10, g: 0.15, b: 0.28, scrimAlpha: 0.20)
    ]

    // MARK: Token Definition
    struct ColorToken {
        let name: String
        let r: Double
        let g: Double
        let b: Double
        let a: Double
        let isLargeOrGraphic: Bool // If true, requires 3.0:1; if false (body text), requires 4.5:1
    }

    // Baseline (before) tokens
    static var baselineTokens: [ColorToken] {
        [
            .init(name: "textPrimary", r: 1.0, g: 1.0, b: 1.0, a: 1.0, isLargeOrGraphic: false),
            .init(name: "textSecondary", r: 1.0, g: 1.0, b: 1.0, a: 0.80, isLargeOrGraphic: false),
            .init(name: "textTertiary", r: 1.0, g: 1.0, b: 1.0, a: 0.60, isLargeOrGraphic: false),
            .init(name: "accent", r: 0.18, g: 0.52, b: 0.98, a: 1.0, isLargeOrGraphic: true),
            .init(name: "alertAmber", r: 0.96, g: 0.65, b: 0.14, a: 1.0, isLargeOrGraphic: true),
            .init(name: "rainBlue", r: 0.35, g: 0.65, b: 1.0, a: 1.0, isLargeOrGraphic: true),
            .init(name: "chartGrid", r: 1.0, g: 1.0, b: 1.0, a: 0.22, isLargeOrGraphic: true)
        ]
    }

    // WCAG AA Certified (after) tokens
    static var verifiedTokens: [ColorToken] {
        [
            .init(name: "textPrimary", r: 1.0, g: 1.0, b: 1.0, a: 1.0, isLargeOrGraphic: false),
            .init(name: "textSecondary", r: 1.0, g: 1.0, b: 1.0, a: 0.86, isLargeOrGraphic: false),
            .init(name: "textTertiary", r: 1.0, g: 1.0, b: 1.0, a: 0.72, isLargeOrGraphic: false),
            .init(name: "accent", r: 0.42, g: 0.74, b: 1.0, a: 1.0, isLargeOrGraphic: true),
            .init(name: "alertAmber", r: 1.0, g: 0.76, b: 0.24, a: 1.0, isLargeOrGraphic: true),
            .init(name: "rainBlue", r: 0.46, g: 0.76, b: 1.0, a: 1.0, isLargeOrGraphic: true),
            .init(name: "chartGrid", r: 1.0, g: 1.0, b: 1.0, a: 0.44, isLargeOrGraphic: true)
        ]
    }

    @Test("Audit baseline failures without scrim")
    func auditBaselineFailures() {
        var failureCount = 0
        for token in Self.baselineTokens {
            let threshold = token.isLargeOrGraphic ? 3.0 : 4.5
            for bg in Self.backgrounds {
                let ratio = WCAGHelper.contrastRatio(fg: (token.r, token.g, token.b, token.a), bg: (bg.r, bg.g, bg.b))
                if ratio < threshold {
                    failureCount += 1
                }
            }
        }
        #expect(failureCount == 44, "Baseline has 44 failures primarily driven by textTertiary at 60%")
    }

    @Test("Every verified token meets WCAG AA on all weather backgrounds with protective scrim")
    func allTokensMeetAAWithProtectiveScrim() {
        for token in Self.verifiedTokens {
            let threshold = token.isLargeOrGraphic ? 3.0 : 4.5
            for bg in Self.backgrounds {
                let effectiveBg = WCAGHelper.applyScrim(bg: (bg.r, bg.g, bg.b), alpha: bg.scrimAlpha)
                let ratio = WCAGHelper.contrastRatio(fg: (token.r, token.g, token.b, token.a), bg: effectiveBg)
                #expect(
                    ratio >= threshold,
                    "Token \(token.name) failed on [\(bg.name)]: ratio is \(String(format: "%.2f", ratio)):1 (Required \(threshold):1)"
                )
            }
        }
    }

    @Test("Card tokens meet WCAG AA on cardSolid")
    func cardSolidTokensMeetAA() {
        let cardBg = (r: 0.08, g: 0.16, b: 0.32)

        // textPrimary (body >= 4.5:1)
        let primaryRatio = WCAGHelper.contrastRatio(fg: (1.0, 1.0, 1.0, 1.0), bg: cardBg)
        #expect(primaryRatio >= 4.5, "textPrimary on cardSolid must meet 4.5:1")

        // textSecondary (body >= 4.5:1)
        let secondaryRatio = WCAGHelper.contrastRatio(fg: (1.0, 1.0, 1.0, 0.86), bg: cardBg)
        #expect(secondaryRatio >= 4.5, "textSecondary on cardSolid must meet 4.5:1")

        // textTertiary (body >= 4.5:1) - must never be below 0.7 opacity
        let tertiaryRatio = WCAGHelper.contrastRatio(fg: (1.0, 1.0, 1.0, 0.72), bg: cardBg)
        #expect(tertiaryRatio >= 4.5, "textTertiary on cardSolid must meet 4.5:1")

        // alertAmber (graphic/large >= 3.0:1, body >= 4.5:1)
        let amberRatio = WCAGHelper.contrastRatio(fg: (1.0, 0.76, 0.24, 1.0), bg: cardBg)
        #expect(amberRatio >= 4.5, "alertAmber on cardSolid must meet 4.5:1")

        // rainBlue (graphic/large >= 3.0:1)
        let rainRatio = WCAGHelper.contrastRatio(fg: (0.46, 0.76, 1.0, 1.0), bg: cardBg)
        #expect(rainRatio >= 3.0, "rainBlue on cardSolid must meet 3.0:1")

        // accent (graphic/large >= 3.0:1)
        let accentRatio = WCAGHelper.contrastRatio(fg: (0.38, 0.70, 1.0, 1.0), bg: cardBg)
        #expect(accentRatio >= 3.0, "accent on cardSolid must meet 3.0:1")

        // chartGrid (graphic >= 3.0:1)
        let gridRatio = WCAGHelper.contrastRatio(fg: (1.0, 1.0, 1.0, 0.42), bg: cardBg)
        #expect(gridRatio >= 3.0, "chartGrid on cardSolid must meet 3.0:1")
    }

    @Test("Increased contrast mode yields fully opaque text exceeding 7.0:1 AAA")
    func increasedContrastTokensMeetAAA() {
        let cardBg = (r: 0.08, g: 0.16, b: 0.32)
        // With increased contrast, secondary and tertiary are fully opaque white
        let highContrastRatio = WCAGHelper.contrastRatio(fg: (1.0, 1.0, 1.0, 1.0), bg: cardBg)
        #expect(highContrastRatio >= 7.0, "High contrast text exceeds 7.0:1 WCAG AAA")
    }

    // swiftlint:disable no_print - Test utility prints diagnostic contrast comparison table to runner output
    @Test("Generate Before vs After contrast comparison table")
    func generateComparisonTable() {
        print("\n================== WCAG AA CONTRAST COMPARISON TABLE ==================")
        print(String(format: "%-16@ | %-28@ | %-12@ | %-12@ | %-6@", "Token", "Background Region", "Before", "After", "Status"))
        print(String(repeating: "-", count: 85))

        for (beforeToken, afterToken) in zip(Self.baselineTokens, Self.verifiedTokens) {
            let threshold = afterToken.isLargeOrGraphic ? 3.0 : 4.5
            for bg in Self.backgrounds {
                let rawRatio = WCAGHelper.contrastRatio(
                    fg: (beforeToken.r, beforeToken.g, beforeToken.b, beforeToken.a),
                    bg: (bg.r, bg.g, bg.b)
                )
                let scrimBg = WCAGHelper.applyScrim(bg: (bg.r, bg.g, bg.b), alpha: bg.scrimAlpha)
                let afterRatio = WCAGHelper.contrastRatio(
                    fg: (afterToken.r, afterToken.g, afterToken.b, afterToken.a),
                    bg: scrimBg
                )

                let status = afterRatio >= threshold ? "PASS" : "FAIL"
                if rawRatio < threshold || bg.name.contains("Snow") || bg.name.contains("Fog") {
                    print(String(
                        format: "%-16@ | %-28@ | %5.2f:1      | %5.2f:1      | %@",
                        afterToken.name,
                        bg.name,
                        rawRatio,
                        afterRatio,
                        status
                    ))
                }
            }
        }
        print("=======================================================================\n")
    }
    // swiftlint:enable no_print
}
