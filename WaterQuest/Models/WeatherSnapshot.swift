import Foundation

struct WeatherSnapshot: Codable {
    var temperatureC: Double
    var humidityPercent: Double
    var condition: String

    static let mild = WeatherSnapshot(temperatureC: 20, humidityPercent: 50, condition: "Mild")
}
