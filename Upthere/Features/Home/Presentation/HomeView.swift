import SwiftUI

public struct HomeView: View {
    public init(viewModel: HomeViewModel? = nil) {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
                headerSection
                locationAndDateSection
                currentWeatherSection
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var headerSection: some View {
        HStack {
            Text("UpThere")
                .font(.title2.weight(.bold))
                .tracking(0.5)

            Spacer()
        }
    }

    private var locationAndDateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)

                Text("Ghaziabad")
                    .font(.title.weight(.semibold))
            }

            Text("Monday, Oct 5 • 8:30 PM")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentWeatherSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 64))
                .padding(.bottom, 4)

            Text("28.5°")
                .font(.system(size: 80, weight: .thin, design: .rounded))
                .tracking(-2)

            Text("Partly Cloudy")
                .font(.title3.weight(.medium))

            Text("Feels like 30°")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Text("H 31°")
                Text("L 24°")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.6))
        )
    }
}

#Preview {
    HomeView(
        viewModel: HomeViewModel(
            getWeatherUseCase: GetWeatherUseCase(
                repository: MockWeatherRepository()
            )
        )
    )
}
