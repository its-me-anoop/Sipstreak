import Foundation
import CoreLocation
import WeatherKit

@MainActor
final class WeatherClient: ObservableObject {
    enum Status {
        case idle
        case loading
        case failed
    }

    @Published var currentWeather: WeatherSnapshot?
    @Published var status: Status = .idle

    private let weatherService = WeatherService.shared
    private let locationManager: LocationManager

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    func refresh() async {
        guard let location = locationManager.lastLocation else {
            status = .failed
            return
        }
        status = .loading
        do {
            let weather = try await weatherService.weather(for: location)
            let tempC = weather.currentWeather.temperature.converted(to: .celsius).value
            let humidity = weather.currentWeather.humidity * 100
            let snapshot = WeatherSnapshot(temperatureC: tempC, humidityPercent: humidity, condition: weather.currentWeather.condition.description)
            currentWeather = snapshot
            status = .idle
        } catch {
            status = .failed
            print("Weather fetch failed: \(error)")
        }
    }
}
