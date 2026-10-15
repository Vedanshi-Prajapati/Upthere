import SwiftUI

public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel
    private let locationService: LocationService
    @State private var showLocationPermission = false

    public var condition: String?
    public var symbolName: String?

    public init(
        viewModel: SettingsViewModel? = nil,
        locationService: LocationService? = nil,
        condition: String? = nil,
        symbolName: String? = nil
    ) {
        self.viewModel = viewModel ?? SettingsViewModel()
        self.locationService = locationService ?? .shared
        self.condition = condition
        self.symbolName = symbolName
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - Weather
                Section {
                    NavigationLink {
                        UnitPickerView(
                            title: "Temperature unit",
                            options: TemperatureUnit.allCases.map { $0.rawValue },
                            selected: viewModel.temperatureUnit.rawValue,
                            condition: condition,
                            symbolName: symbolName
                        ) { newValue in
                            if let unit = TemperatureUnit(rawValue: newValue) {
                                viewModel.temperatureUnit = unit
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge(icon: "thermometer.medium", color: .orange)
                            Text("Temperature unit")
                                .foregroundStyle(.white)
                            Spacer()
                            Text(viewModel.temperatureUnit.shortLabel)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    NavigationLink {
                        UnitPickerView(
                            title: "Wind speed unit",
                            options: WindSpeedUnit.allCases.map { $0.rawValue },
                            selected: viewModel.windSpeedUnit.rawValue,
                            condition: condition,
                            symbolName: symbolName
                        ) { newValue in
                            if let unit = WindSpeedUnit(rawValue: newValue) {
                                viewModel.windSpeedUnit = unit
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge(icon: "wind", color: Color(red: 45/255, green: 175/255, blue: 195/255))
                            Text("Wind speed unit")
                                .foregroundStyle(.white)
                            Spacer()
                            Text(viewModel.windSpeedUnit.rawValue)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    NavigationLink {
                        UnitPickerView(
                            title: "Precipitation unit",
                            options: PrecipitationUnit.allCases.map { $0.rawValue },
                            selected: viewModel.precipitationUnit.rawValue,
                            condition: condition,
                            symbolName: symbolName
                        ) { newValue in
                            if let unit = PrecipitationUnit(rawValue: newValue) {
                                viewModel.precipitationUnit = unit
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge(icon: "drop.fill", color: Color(red: 0/255, green: 122/255, blue: 255/255))
                            Text("Precipitation unit")
                                .foregroundStyle(.white)
                            Spacer()
                            Text(viewModel.precipitationUnit.rawValue)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                } header: {
                    Text("Weather")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.cardMaterial))

                // MARK: - Notifications
                Section {
                    Toggle(isOn: $viewModel.weatherChangesEnabled) {
                        HStack(spacing: 12) {
                            iconBadge(icon: "cloud.fill", color: Color(red: 50/255, green: 155/255, blue: 245/255))
                            Text("Weather changes")
                                .foregroundStyle(.white)
                        }
                    }
                    .tint(AppTheme.accent)

                    Toggle(isOn: $viewModel.rainAlertsEnabled) {
                        HStack(spacing: 12) {
                            iconBadge(icon: "umbrella.fill", color: Color(red: 88/255, green: 86/255, blue: 214/255))
                            Text("Rain alerts")
                                .foregroundStyle(.white)
                        }
                    }
                    .tint(AppTheme.accent)

                    Toggle(isOn: $viewModel.severeAlertsEnabled) {
                        HStack(spacing: 12) {
                            iconBadge(icon: "exclamationmark.triangle.fill", color: Color(red: 255/255, green: 59/255, blue: 48/255))
                            Text("Severe weather alerts")
                                .foregroundStyle(.white)
                        }
                    }
                    .tint(AppTheme.accent)
                } header: {
                    Text("Notifications")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.cardMaterial))

                // MARK: - Location
                Section {
                    HStack(spacing: 12) {
                        iconBadge(icon: "location.fill", color: Color(red: 0/255, green: 122/255, blue: 255/255))
                        Text("Current location")
                            .foregroundStyle(.white)
                        Spacer()
                        Text(viewModel.currentLocationName)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Button {
                        if locationService.authorizationStatus == .notDetermined {
                            showLocationPermission = true
                        } else if let url = URL(string: UIApplication.openSettingsURLString),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge(icon: "hand.raised.fill", color: Color(red: 52/255, green: 199/255, blue: 89/255))
                            Text("Location permissions")
                                .foregroundStyle(.white)
                            Spacer()
                            Text(viewModel.locationPermission)
                                .foregroundStyle(AppTheme.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                } header: {
                    Text("Location")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.cardMaterial))

                // MARK: - Appearance
                Section {
                    Picker("Appearance", selection: $viewModel.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .glassEffect(cornerRadius: 12)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                } header: {
                    Text("Appearance")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                // MARK: - Text Size
                Section {
                    Picker("Text Size", selection: $viewModel.textSize) {
                        ForEach(TextSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .glassEffect(cornerRadius: 12)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                } header: {
                    Text("Text Size")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                } footer: {
                    Text("Preview of Dynamic Type. Layouts reflow; nothing truncates.")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(AppTheme.textTertiary)
                }

                // MARK: - About
                Section {
                    HStack(spacing: 12) {
                        iconBadge(icon: "cloud.sun.fill", color: Color(red: 50/255, green: 155/255, blue: 245/255))
                        Text("Weather data provider")
                            .foregroundStyle(.white)
                        Spacer()
                        Text(viewModel.weatherDataProvider)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Button {
                        if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge(icon: "apple.logo", color: Color.white.opacity(0.3))
                            Text("Apple Weather attribution")
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }

                    HStack(spacing: 12) {
                        iconBadge(icon: "info.circle.fill", color: .gray)
                        Text("App version")
                            .foregroundStyle(.white)
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } header: {
                    Text("About")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.cardMaterial))

                // MARK: - Apple Weather Legal Footer
                Section {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Weather")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.85))

                        Link("Data Sources & Legal Notices", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .underline()
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WeatherBackgroundView(condition: condition, symbolName: symbolName))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .fullScreenCover(isPresented: $showLocationPermission) {
                LocationPermissionView(
                    onAllow: {
                        showLocationPermission = false
                        locationService.requestAuthorization()
                    },
                    onSearchInstead: {
                        showLocationPermission = false
                    }
                )
            }
        }
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
}

#Preview {
    SettingsView()
}
