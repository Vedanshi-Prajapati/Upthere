import SwiftUI

/// City search sheet shown when the user taps "+" on the Locations screen.
/// Displays a search bar and suggestion chips.
public struct CitySearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let suggestions = ["Pune", "Jaipur", "Chennai", "Kolkata"]
    public var onCitySelected: (String) -> Void

    public init(onCitySelected: @escaping (String) -> Void) {
        self.onCitySelected = onCitySelected
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.40))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textSecondary)
                    .font(.system(size: 16))

                TextField("", text: $searchText, prompt:
                    Text("Search for a city").foregroundColor(AppTheme.textSecondary)
                )
                .foregroundStyle(.white)
                .font(.system(size: 16))
                .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // Suggestions
            if searchText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggestions")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(filteredSuggestions, id: \.self) { city in
                                Button {
                                    onCitySelected(city)
                                    dismiss()
                                } label: {
                                    Text(city)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(.white.opacity(0.88))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            } else {
                // Search results
                let results = filteredSuggestions
                if results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("No results found")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 0) {
                        ForEach(results, id: \.self) { city in
                            Button {
                                onCitySelected(city)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(AppTheme.accent)
                                    Text(city)
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)

                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
            }

            Spacer()
        }
        .background(
            AppTheme.backgroundGradient.ignoresSafeArea()
        )
    }

    private var filteredSuggestions: [String] {
        let allCities = [
            "Pune", "Jaipur", "Chennai", "Kolkata",
            "Delhi", "Mumbai", "Bengaluru", "Hyderabad",
            "Ahmedabad", "Lucknow", "Chandigarh", "Kochi"
        ]
        if searchText.isEmpty { return suggestions }
        return allCities.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
}

#Preview {
    CitySearchSheet(onCitySelected: { _ in })
}
