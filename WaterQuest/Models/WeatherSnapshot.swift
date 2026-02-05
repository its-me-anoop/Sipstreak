import Foundation

struct WeatherSnapshot: Codable {
    var temperatureC: Double
    var humidityPercent: Double
    /// Localized, human-readable condition string (e.g. "Sunny")
    var condition: String
    /// Stable enum-case name from WeatherCondition (e.g. "clear", "rain").
    /// Defaults to empty string so existing persisted data decodes cleanly.
    var conditionKey: String = ""

    static let mild = WeatherSnapshot(temperatureC: 20, humidityPercent: 50, condition: "Mild", conditionKey: "")

    /// Maps a WeatherCondition case name to the best matching SF Symbol.
    static func sfSymbol(for key: String) -> String {
        switch key {
        // Clear / sunny
        case "clear":                       return "sun.max.fill"
        case "mostlyClear":                 return "sun.min.fill"
        case "hot":                         return "sun.max.fill"

        // Cloudy
        case "partlyCloudy":                return "cloud.sun.fill"
        case "mostlyCloudy":                return "cloud.fill"
        case "cloudy":                      return "cloud.fill"

        // Rain
        case "drizzle":                     return "cloud.drizzle.fill"
        case "rain":                        return "cloud.rain.fill"
        case "heavyRain":                   return "cloud.heavyrain.fill"
        case "sunShowers":                  return "cloud.sun.rain.fill"

        // Thunderstorms
        case "isolatedThunderstorms":       return "cloud.bolt.rain.fill"
        case "scatteredThunderstorms":      return "cloud.bolt.rain.fill"
        case "thunderstorms":               return "cloud.bolt.rain.fill"
        case "strongStorms":                return "cloud.bolt.rain.fill"

        // Snow
        case "flurries":                    return "cloud.snow.fill"
        case "snow":                        return "cloud.snow.fill"
        case "heavySnow":                   return "cloud.snow.fill"
        case "sunFlurries":                 return "sun.snow.fill"
        case "blowingSnow":                 return "wind.snow.fill"
        case "blizzard":                    return "cloud.snow.fill"

        // Winter / freezing
        case "sleet":                       return "cloud.sleet.fill"
        case "wintryMix":                   return "cloud.sleet.fill"
        case "freezingDrizzle":             return "cloud.drizzle.fill"
        case "freezingRain":                return "cloud.rain.fill"
        case "frigid":                      return "thermometer.snowflake"

        // Hail
        case "hail":                        return "cloud.hail.fill"

        // Visibility / atmosphere
        case "foggy":                       return "cloud.fog.fill"
        case "haze":                        return "cloud.fog.fill"
        case "smoky":                       return "cloud.fog.fill"
        case "blowingDust":                 return "wind"

        // Wind
        case "breezy":                      return "wind"
        case "windy":                       return "wind"

        default:                            return "cloud.fill"
        }
    }
}
