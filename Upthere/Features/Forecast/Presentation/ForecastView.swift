import SwiftUI

public struct ForecastView: View {
    @State private var viewModel: HomeViewModel
    @State private var selectedTab: ForecastTab = .daily

    public enum ForecastTab {
        case hourly, daily
    }

    public init(viewModel: HomeViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            switch viewModel.state {
            case .idle, .loading:
                ProgressView().tint(.white)
            case .error(let msg):
                Text(msg).foregroundStyle(AppTheme.textSecondary)
            case .loaded(let weather):
                VStack(spacing: 0) {
                    header(weather: weather)
                    picker
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        if selectedTab == .daily {
                            dailyView(weather: weather)
                        } else {
                            hourlyView(weather: weather)
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
    }

    private func header(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forecast")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Text(weather.cityName)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 24)
    }

    private var picker: some View {
        HStack(spacing: 0) {
            pickerButton(title: "Hourly", tab: .hourly)
            pickerButton(title: "Daily", tab: .daily)
        }
        .padding(4)
        .background(
            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func pickerButton(title: String, tab: ForecastTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if selectedTab == tab {
                            Capsule().fill(Color.white.opacity(0.2))
                        } else {
                            Color.clear
                        }
                    }
                )
        }
    }

    private func dailyView(weather: Weather) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(weather.dailyForecast.enumerated()), id: \.offset) { index, daily in
                DailyWeatherRow(daily: daily)
                if index < weather.dailyForecast.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardGlass)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 110)
    }

    private func hourlyView(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 24) {

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(weather.hourlyForecast) { hourly in
                        HourlyCard(hourly: hourly)
                    }
                }
                .padding(.horizontal, 20)
            }


            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Now")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(weather.condition)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 20)

                let rows: [(String, String, String, String, String, String)] = [
                    ("Temperature", "\(Int(weather.temperature))°", "Feels like \(Int(weather.feelsLike))°",
                     "Precipitation", "\(weather.precipitationChance)%", "0.0 mm"),
                    ("Wind", "\(Int(weather.windSpeed)) km/h", "Gusts \(Int(weather.windSpeed + 5)) km/h",
                     "UV index", "\(weather.uvIndex)", weather.uvDescription),
                    ("Humidity", "\(weather.humidity)%", "",
                     "Cloud cover", "30%", "")
                ]

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: 0) {
                            MetricCell(title: row.0, value: row.1, subtitle: row.2)
                            Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1)
                            MetricCell(title: row.3, value: row.4, subtitle: row.5)
                        }
                        if rows.firstIndex(where: { $0.0 == row.0 }) != rows.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.cardGlass)
                )
                .padding(.horizontal, 20)
            }
            

            VStack(alignment: .leading, spacing: 16) {
                Text("Precipitation")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)

                VStack {

                    Rectangle().fill(Color.clear).frame(height: 100)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.cardGlass)
                )
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 110)
        }
    }
}

private struct HourlyCard: View {
    let hourly: HourlyWeather

    var body: some View {
        let isNow = hourly.time.lowercased() == "now"
        VStack(spacing: 8) {
            Text(hourly.time)
                .font(.system(size: 15, weight: isNow ? .semibold : .medium))
                .foregroundStyle(.white)
            
            Image(systemName: "sun.max.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 24))
                .padding(.vertical, 4)
            
            Text("\(Int(hourly.temperature))°")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("\(Int(hourly.precipitationProbability * 100))%")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(width: 80)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isNow ? Color.white.opacity(0.15) : AppTheme.cardGlass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isNow ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

private struct DailyWeatherRow: View {
    let daily: DailyWeather

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(daily.dayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(daily.date)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(width: 60, alignment: .leading)

            VStack(spacing: 2) {
                Image(systemName: daily.symbolName)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 20))
                if daily.precipitationProbability > 0 {
                    Text("\(Int(daily.precipitationProbability * 100))%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                }
            }
            .frame(width: 40)

            Text("\(Int(daily.lowTemperature))°")
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .frame(width: 32, alignment: .trailing)


            GeometryReader { geo in
                let totalRange: Double = 40.0 - 15.0
                let startPos = (daily.lowTemperature - 15.0) / totalRange
                let widthPercent = (daily.highTemperature - daily.lowTemperature) / totalRange
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(LinearGradient(colors: [Color(red: 0.4, green: 0.7, blue: 1.0), Color.yellow], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, widthPercent * geo.size.width))
                        .offset(x: max(0, startPos * geo.size.width))
                }
            }
            .frame(height: 4)

            Text("\(Int(daily.highTemperature))°")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}

private struct MetricCell: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}
