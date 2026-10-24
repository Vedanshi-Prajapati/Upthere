import SwiftUI

/// Reusable picker screen for unit selection (Temperature, Wind speed, Precipitation).
/// Shows a list of options with a checkmark on the currently selected one.
public struct UnitPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let options: [String]
    @State private var selected: String
    let condition: String?
    let symbolName: String?
    let onSelect: (String) -> Void

    public init(
        title: String,
        options: [String],
        selected: String,
        condition: String? = nil,
        symbolName: String? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        self.title = title
        self.options = options
        self._selected = State(initialValue: selected)
        self.condition = condition
        self.symbolName = symbolName
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack {
            WeatherBackgroundView(condition: condition, symbolName: symbolName)

            VStack(spacing: 0) {
                // Card
                WeatherCard(cornerRadius: AppTheme.radiusCard, padding: EdgeInsets()) {
                    VStack(spacing: 0) {
                        ForEach(Array(options.enumerated()), id: \.element) { index, option in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selected = option
                                    onSelect(option)
                                }
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(.body)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    if selected == option {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)

                            if index < options.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(height: 1)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.14))
                        )
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview("Temperature") {
    NavigationStack {
        UnitPickerView(
            title: "Temperature unit",
            options: ["Celsius (°C)", "Fahrenheit (°F)"],
            selected: "Celsius (°C)"
        ) { _ in }
    }
}

#Preview("Wind Speed") {
    NavigationStack {
        UnitPickerView(
            title: "Wind speed unit",
            options: ["km/h", "mph", "m/s"],
            selected: "km/h"
        ) { _ in }
    }
}
