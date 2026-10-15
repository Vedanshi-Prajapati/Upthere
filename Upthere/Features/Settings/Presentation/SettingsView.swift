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
            ZStack {
                WeatherBackgroundView(condition: condition, symbolName: symbolName)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        header

                        // 1. Weather Units
                        weatherUnitsSection

                        // 2. Notifications
                        notificationsSection

                        // 3. Location
                        locationSection

                        // 4. Appearance
                        appearanceSection

                        // 5. Text Size
                        textSizeSection

                        // 6. About
                        aboutSection

                        // 7. Legal attribution
                        legalFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, AppTheme.tabBarClearance)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - 1. Weather Units
    private var weatherUnitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Weather")

            groupedCard {
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
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(viewModel.temperatureUnit.shortLabel)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textSecondary)
                        chevron
                    }
                }
                .buttonStyle(.plain)

                divider

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
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(viewModel.windSpeedUnit.rawValue)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textSecondary)
                        chevron
                    }
                }
                .buttonStyle(.plain)

                divider

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
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(viewModel.precipitationUnit.rawValue)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textSecondary)
                        chevron
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 2. Notifications
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Notifications")

            groupedCard {
                Toggle(isOn: $viewModel.weatherChangesEnabled) {
                    HStack(spacing: 12) {
                        iconBadge(icon: "cloud.fill", color: Color(red: 50/255, green: 155/255, blue: 245/255))
                        Text("Weather changes")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .tint(AppTheme.accent)

                divider

                Toggle(isOn: $viewModel.rainAlertsEnabled) {
                    HStack(spacing: 12) {
                        iconBadge(icon: "umbrella.fill", color: Color(red: 88/255, green: 86/255, blue: 214/255))
                        Text("Rain alerts")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .tint(AppTheme.accent)

                divider

                Toggle(isOn: $viewModel.severeAlertsEnabled) {
                    HStack(spacing: 12) {
                        iconBadge(icon: "exclamationmark.triangle.fill", color: Color(red: 255/255, green: 59/255, blue: 48/255))
                        Text("Severe weather alerts")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .tint(AppTheme.accent)
            }
        }
    }

    // MARK: - 3. Location
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Location")

            groupedCard {
                HStack(spacing: 12) {
                    iconBadge(icon: "location.fill", color: Color(red: 0/255, green: 122/255, blue: 255/255))
                    Text("Current location")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(viewModel.currentLocationName)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                divider

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
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(viewModel.locationPermission)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textSecondary)
                        chevron
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 4. Appearance
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Appearance")

            Picker("Appearance", selection: $viewModel.appearanceMode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .glassEffect(cornerRadius: 12)
        }
    }

    // MARK: - 5. Text Size
    private var textSizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Text Size")

            Picker("Text Size", selection: $viewModel.textSize) {
                ForEach(TextSize.allCases, id: \.self) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .glassEffect(cornerRadius: 12)

            Text("Preview of Dynamic Type. Layouts reflow cleanly without truncation.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.top, 2)
        }
    }

    // MARK: - 6. About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("About")

            groupedCard {
                HStack(alignment: .center, spacing: 12) {
                    iconBadge(icon: "cloud.sun.fill", color: Color(red: 50/255, green: 155/255, blue: 245/255))
                    Text("Weather data provider")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 8)
                    Text(viewModel.weatherDataProvider)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
                }

                divider

                Button {
                    if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        iconBadge(icon: "apple.logo", color: Color.white.opacity(0.3))
                        Text("Apple Weather attribution")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                divider

                HStack(spacing: 12) {
                    iconBadge(icon: "info.circle.fill", color: .gray)
                    Text("App version")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(viewModel.appVersion)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 7. Legal Footer
    private var legalFooter: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 13, weight: .semibold))
                Text("Weather")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(AppTheme.textSecondary)

            Link("Data Sources & Legal Notices", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textTertiary)
                .underline()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Helper Views
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.leading, 4)
    }

    private func groupedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardGlass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 0.8)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.separator)
            .frame(height: 0.8)
            .padding(.vertical, 2)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.textTertiary)
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
