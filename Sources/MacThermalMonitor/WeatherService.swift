import Foundation

struct WeatherReport: Sendable {
    let city: String
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let weatherCode: Int
    let fetchedAt: Date

    func condition(chinese: Bool) -> String {
        switch weatherCode {
        case 0: chinese ? "晴朗" : "Clear"
        case 1...3: chinese ? "多云" : "Partly cloudy"
        case 45, 48: chinese ? "有雾" : "Fog"
        case 51...67, 80...82: chinese ? "有雨" : "Rain"
        case 71...77, 85, 86: chinese ? "有雪" : "Snow"
        case 95...99: chinese ? "雷暴" : "Thunderstorm"
        default: chinese ? "未知" : "Unknown"
        }
    }
}

actor WeatherService {
    func currentWeather(for city: String) async throws -> WeatherReport {
        let location = try await location(for: city)
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw WeatherError.unavailable }
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)
        return WeatherReport(
            city: location.name,
            temperature: forecast.current.temperature_2m,
            apparentTemperature: forecast.current.apparent_temperature,
            humidity: forecast.current.relative_humidity_2m,
            windSpeed: forecast.current.wind_speed_10m,
            weatherCode: forecast.current.weather_code,
            fetchedAt: .now
        )
    }

    private func location(for city: String) async throws -> Location {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [URLQueryItem(name: "name", value: city), URLQueryItem(name: "count", value: "1"), URLQueryItem(name: "language", value: "zh")]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw WeatherError.unavailable }
        guard let location = try JSONDecoder().decode(GeocodingResponse.self, from: data).results?.first else { throw WeatherError.cityNotFound }
        return location
    }

    private struct GeocodingResponse: Decodable { let results: [Location]? }
    private struct Location: Decodable { let name: String; let latitude: Double; let longitude: Double }
    private struct ForecastResponse: Decodable {
        let current: Current
        struct Current: Decodable {
            let temperature_2m: Double
            let relative_humidity_2m: Int
            let apparent_temperature: Double
            let weather_code: Int
            let wind_speed_10m: Double
        }
    }
}

enum WeatherError: LocalizedError {
    case cityNotFound, unavailable
    var errorDescription: String? {
        switch self {
        case .cityNotFound: "City not found"
        case .unavailable: "Weather service is unavailable"
        }
    }
}
