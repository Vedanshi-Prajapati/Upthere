import SwiftUI
import CoreLocation

public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel
    private let locationService: LocationService
    @State private var showLocationPermission = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public var condition: String?
    public var symbolName: String?

    public init(
        viewModel: SettingsViewModel? = nil,
        locationService: LocationService? = nil,
        condition: String? = nil,
        symbolName: String? = nil
    ) {
        let vm = viewModel ?? SettingsViewModel(locationService: locationService)
        self.viewModel = vm
        self.locationService = locationService ?? vm.locationService
        self.condition = condition
        self.symbolName = symbolName
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                WeatherBackgroundView(condition: condition, symbolName: symbolName)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingXXLarge) {
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

                        // 5. About
                        aboutSection
                    }
                    .padding(.horizontal, AppTheme.spacingXLarge)
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
        .task {
            await viewModel.checkNotificationStatus()
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXSmall) {
            Text("Settings")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppTheme.spacingSmall)
    }

    // MARK: - 1. Weather Units
    private var weatherUnitsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
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
                    HStack(spacing: AppTheme.spacingMedium) {
                        iconBadge(icon: "thermometer.medium", color: .orange)
                        Text("Temperature unit")
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(viewModel.temperatureUnit.shortLabel)
                            .font(.subheadline)
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
                    HStack(spacing: AppTheme.spacingMedium) {
                        iconBadge(icon: "wind", color: Color(red: 45/255, green: 175/255, blue: 195/255))
                        Text("Wind speed unit")
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(viewModel.windSpeedUnit.rawValue)
                            .font(.subheadline)
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
                    HStack(spacing: AppTheme.spacingMedium) {
                        iconBadge(icon: "drop.fill", color: Color(red: 0/255, green: 122/255, blue: 255/255))
                        Text("Precipitation unit")
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(viewModel.precipitationUnit.rawValue)
                            .font(.subheadline)
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
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            sectionHeader("Notifications")

            groupedCard {
                Toggle(isOn: Binding(
                    get: { viewModel.rainAlertsEnabled },
                    set: { newValue in
                        Task { @MainActor in
                            await viewModel.setRainAlerts(newValue)
                        }
                    }
                )) {
                    HStack(spacing: AppTheme.spacingMedium) {
                        iconBadge(icon: "umbrella.fill", color: Color(red: 88/255, green: 86/255, blue: 214/255))
                        Text("Rain alerts")
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .tint(AppTheme.accent)

                divider

                Toggle(isOn: Binding(
                    get: { viewModel.severeAlertsEnabled },
                    set: { newValue in
                        Task { @MainActor in
                            await viewModel.setSevereAlerts(newValue)
                        }
                    }
                )) {
                    HStack(spacing: AppTheme.spacingMedium) {
                        iconBadge(icon: "exclamationmark.triangle.fill", color: Color(red: 255/255, green: 59/255, blue: 48/255))
                        Text("Severe weather alerts")
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .tint(AppTheme.accent)
            }

            if viewModel.notificationsDenied {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    HStack(spacing: AppTheme.spacingMedium) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Notifications are off in iOS Settings")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                }
                .padding(AppTheme.spacingMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - 3. Location
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            sectionHeader("Location")

            groupedCard {
                HStack(spacing: AppTheme.spacingMedium) {
                    iconBadge(icon: "location.fill", color: Color(red: 0/255, green: 122/255, blue: 255/255))
                    Text("Current location")
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(viewModel.currentLocationName)
                        .font(.subheadline)
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
                    HStack(spacing: AppTheme.spacingMedium) {
                        iconBadge(icon: "hand.raised.fill", color: Color(red: 52/255, green: 199/255, blue: 89/255))
                        Text("Location permissions")
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(viewModel.locationPermission)
                            .font(.subheadline)
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
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            sectionHeader("Appearance")

            Group {
                if reduceTransparency {
                    Picker("Appearance", selection: $viewModel.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .background(Color(white: 0.18), in: RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                } else {
                    Picker("Appearance", selection: $viewModel.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                }
            }

            Text("Text size follows your iPhone’s Display & Brightness setting.")
                .font(AppFont.footnote)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 4)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - 5. About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            sectionHeader("About")

            groupedCard {
                HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
                    iconBadge(icon: "cloud.sun.fill", color: Color(red: 50/255, green: 155/255, blue: 245/255))
                    Text("Weather data provider")
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 8)
                    Text(viewModel.weatherDataProvider)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
                }

                divider

                AttributionView()
                    .padding(.vertical, 4)

                divider

                HStack(spacing: AppTheme.spacingMedium) {
                    iconBadge(icon: "info.circle.fill", color: .gray)
                    Text("App version")
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(viewModel.appVersion)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Helper Views
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.leading, AppTheme.spacingXXSmall)
    }

    private func groupedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        WeatherCard(padding: AppTheme.spacingCardPadding) {
            VStack(spacing: AppTheme.spacingMedium) {
                content()
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.separator)
            .frame(height: 0.8)
            .padding(.vertical, 2)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.textTertiary)
    }

    private func iconBadge(icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
    }
}

#Preview("Settings") {
    SettingsView()
}

#Preview("Settings AX3") {
    SettingsView()
        .dynamicTypeSize(.accessibility3)
}
