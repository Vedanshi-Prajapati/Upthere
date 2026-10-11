import SwiftUI

public struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showTemperatureUnit = false
    @State private var showWindSpeedUnit = false
    @State private var showPrecipitationUnit = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 28)

                        // MARK: - Weather
                        sectionHeader("Weather")

                        VStack(spacing: 0) {
                            settingsRow(
                                icon: "thermometer.medium",
                                iconColor: .orange,
                                title: "Temperature unit",
                                value: viewModel.temperatureUnit.shortLabel
                            ) {
                                showTemperatureUnit = true
                            }
                            divider
                            settingsRow(
                                icon: "wind",
                                iconColor: Color(red: 45/255, green: 175/255, blue: 195/255),
                                title: "Wind speed unit",
                                value: viewModel.windSpeedUnit.rawValue
                            ) {
                                showWindSpeedUnit = true
                            }
                            divider
                            settingsRow(
                                icon: "drop.fill",
                                iconColor: Color(red: 0/255, green: 122/255, blue: 255/255),
                                title: "Precipitation unit",
                                value: viewModel.precipitationUnit.rawValue
                            ) {
                                showPrecipitationUnit = true
                            }
                        }
                        .glassCard()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                        // MARK: - Notifications
                        sectionHeader("Notifications")

                        VStack(spacing: 0) {
                            toggleRow(
                                icon: "cloud.fill",
                                iconColor: Color(red: 50/255, green: 155/255, blue: 245/255),
                                title: "Weather changes",
                                isOn: $viewModel.weatherChangesEnabled
                            )
                            divider
                            toggleRow(
                                icon: "umbrella.fill",
                                iconColor: Color(red: 88/255, green: 86/255, blue: 214/255),
                                title: "Rain alerts",
                                isOn: $viewModel.rainAlertsEnabled
                            )
                        }
                        .glassCard()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                        // MARK: - Location
                        sectionHeader("Location")

                        VStack(spacing: 0) {
                            infoRow(
                                icon: "location.fill",
                                iconColor: Color(red: 0/255, green: 122/255, blue: 255/255),
                                title: "Current location",
                                value: viewModel.currentLocationName
                            )
                            divider
                            settingsRow(
                                icon: "location.fill",
                                iconColor: Color(red: 52/255, green: 199/255, blue: 89/255),
                                title: "Location permissions",
                                value: viewModel.locationPermission
                            ) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        .glassCard()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                        // MARK: - Appearance
                        sectionHeader("Appearance")

                        segmentedControl(
                            options: AppearanceMode.allCases.map { $0.rawValue },
                            selected: viewModel.appearanceMode.rawValue
                        ) { newValue in
                            if let mode = AppearanceMode(rawValue: newValue) {
                                viewModel.appearanceMode = mode
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                        // MARK: - Text size
                        sectionHeader("Text size")

                        segmentedControl(
                            options: TextSize.allCases.map { $0.rawValue },
                            selected: viewModel.textSize.rawValue
                        ) { newValue in
                            if let size = TextSize(rawValue: newValue) {
                                viewModel.textSize = size
                            }
                        }
                        .padding(.horizontal, 20)

                        Text("Preview of Dynamic Type. Layouts reflow; nothing truncates.")
                            .font(.system(size: 13))
                            .italic()
                            .foregroundStyle(AppTheme.textTertiary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 24)

                        // MARK: - About
                        sectionHeader("About")

                        VStack(spacing: 0) {
                            infoRow(
                                icon: nil,
                                iconColor: .clear,
                                title: "Weather data provider",
                                value: viewModel.weatherDataProvider
                            )
                            divider
                            settingsRow(
                                icon: nil,
                                iconColor: .clear,
                                title: "Apple Weather attribution",
                                value: nil
                            ) {
                                if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            divider
                            infoRow(
                                icon: nil,
                                iconColor: .clear,
                                title: "App version",
                                value: viewModel.appVersion
                            )
                        }
                        .glassCard()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationDestination(isPresented: $showTemperatureUnit) {
                UnitPickerView(
                    title: "Temperature unit",
                    options: TemperatureUnit.allCases.map { $0.rawValue },
                    selected: viewModel.temperatureUnit.rawValue
                ) { newValue in
                    if let unit = TemperatureUnit(rawValue: newValue) {
                        viewModel.temperatureUnit = unit
                    }
                }
            }
            .navigationDestination(isPresented: $showWindSpeedUnit) {
                UnitPickerView(
                    title: "Wind speed unit",
                    options: WindSpeedUnit.allCases.map { $0.rawValue },
                    selected: viewModel.windSpeedUnit.rawValue
                ) { newValue in
                    if let unit = WindSpeedUnit(rawValue: newValue) {
                        viewModel.windSpeedUnit = unit
                    }
                }
            }
            .navigationDestination(isPresented: $showPrecipitationUnit) {
                UnitPickerView(
                    title: "Precipitation unit",
                    options: PrecipitationUnit.allCases.map { $0.rawValue },
                    selected: viewModel.precipitationUnit.rawValue
                ) { newValue in
                    if let unit = PrecipitationUnit(rawValue: newValue) {
                        viewModel.precipitationUnit = unit
                    }
                }
            }
        }
    }

    // MARK: - Components

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 16)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
    }

    private func iconBadge(icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
    }

    private func settingsRow(
        icon: String?,
        iconColor: Color,
        title: String,
        value: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    iconBadge(icon: icon, color: iconColor)
                }

                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)

                Spacer()

                if let value {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(
        icon: String?,
        iconColor: Color,
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            if let icon {
                iconBadge(icon: icon, color: iconColor)
            }

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.white)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func infoRow(
        icon: String?,
        iconColor: Color,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            if let icon {
                iconBadge(icon: icon, color: iconColor)
            }

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }


    private func segmentedControl(
        options: [String],
        selected: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onSelect(option)
                    }
                } label: {
                    Text(option)
                        .font(.system(size: 15, weight: selected == option ? .semibold : .regular))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selected == option {
                                    Capsule()
                                        .fill(AppTheme.accent)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
        )
    }
}

// MARK: - Glass Card Modifier

private struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardGlass)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    fileprivate func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}

#Preview {
    SettingsView()
}
