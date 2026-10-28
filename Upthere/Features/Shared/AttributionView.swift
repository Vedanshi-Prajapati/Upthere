import os
import SwiftUI
import WeatherKit

/// Service that fetches and caches WeatherKit attribution metadata once per session.
@MainActor
@Observable
final class WeatherAttributionService {
    static let shared = WeatherAttributionService()

    private(set) var attribution: WeatherAttribution?
    private var isFetching = false
    private let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WeatherAttribution")

    func loadAttribution() async {
        guard attribution == nil, !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        do {
            self.attribution = try await WeatherService.shared.attribution
        } catch {
            logger.error("Failed to load WeatherKit attribution: \(error.localizedDescription)")
            // Keep nil to trigger text fallback
        }
    }
}

/// WeatherKit attribution mark and legal attribution link view.
/// Adapts to light/dark appearance and scales cleanly across Dynamic Type sizes.
struct AttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var service = WeatherAttributionService.shared

    init() {}

    private var markURL: URL? {
        guard let attr = service.attribution else { return nil }
        return colorScheme == .dark ? attr.combinedMarkDarkURL : attr.combinedMarkLightURL
    }

    var body: some View {
        Group {
            if let attr = service.attribution {
                attributionContent(attr)
            } else {
                fallbackView
            }
        }
        .task {
            await service.loadAttribution()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func attributionContent(_ attr: WeatherAttribution) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                markImageView
                legalLink(url: attr.legalPageURL)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack(spacing: 8) {
                markImageView
                Text("•")
                    .foregroundStyle(AppTheme.textTertiary)
                legalLink(url: attr.legalPageURL)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var markImageView: some View {
        Group {
            if let url = markURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 18)
                    default:
                        Label("Apple Weather", systemImage: "apple.logo")
                            .font(AppFont.captionMedium)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            } else {
                Label("Apple Weather", systemImage: "apple.logo")
                    .font(AppFont.captionMedium)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func legalLink(url: URL) -> some View {
        Link(destination: url) {
            Text("Data Sources")
                .font(AppFont.captionMedium)
                .underline()
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var fallbackView: some View {
        Label("Apple Weather", systemImage: "apple.logo")
            .font(AppFont.captionMedium)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    AttributionView()
        .padding()
        .background(Color.black)
}
