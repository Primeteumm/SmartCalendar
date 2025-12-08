import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Service for fetching weather data from Open-Meteo API
class OpenMeteoService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetch current weather for given coordinates
  /// [latitude] - Latitude coordinate
  /// [longitude] - Longitude coordinate
  /// [cityName] - Optional city name for display (e.g., "Ankara")
  /// Returns formatted string like "Ankara: 15°C, Rainy"
  static Future<String> getCurrentWeather(
    double latitude,
    double longitude, {
    String? cityName,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&timezone=auto'
      );

      debugPrint('Fetching weather from: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Extract current temperature
        final current = data['current'] as Map<String, dynamic>;
        final temperature = current['temperature_2m'] as double;
        final weatherCode = current['weather_code'] as int;

        // Get weather description
        final weatherDescription = getWeatherDescription(weatherCode);

        // Format: "CityName: 15°C, Rainy" or "Location: 15°C, Rainy" if cityName is null
        final locationName = cityName ?? 'Location';
        final result = '$locationName: ${temperature.round()}°C, $weatherDescription';
        
        debugPrint('Weather fetched successfully: $result');
        return result;
      } else {
        debugPrint('Weather API error: ${response.statusCode}');
        final locationName = cityName ?? 'Location';
        return '$locationName: Weather unavailable';
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching weather: $e');
      debugPrint('Stack trace: $stackTrace');
      final locationName = cityName ?? 'Location';
      return '$locationName: Weather unavailable';
    }
  }

  /// Convert WMO weather code to human-readable description
  /// Based on WMO Weather interpretation codes (WW)
  static String getWeatherDescription(int code) {
    // Clear sky
    if (code == 0) {
      return 'Clear';
    }
    // Mainly clear, partly cloudy, and overcast
    else if (code >= 1 && code <= 3) {
      return 'Cloudy';
    }
    // Fog and depositing rime fog
    else if (code >= 45 && code <= 48) {
      return 'Foggy';
    }
    // Drizzle: Light, moderate, and dense intensity
    else if (code >= 51 && code <= 57) {
      return 'Drizzle';
    }
    // Rain: Slight, moderate and heavy intensity
    else if (code >= 61 && code <= 67) {
      return 'Rainy';
    }
    // Freezing Rain: Light and heavy intensity
    else if (code >= 71 && code <= 77) {
      return 'Freezing Rain';
    }
    // Snow fall: Slight, moderate, and heavy intensity
    else if (code >= 71 && code <= 85) {
      return 'Snowy';
    }
    // Snow grains
    else if (code == 86) {
      return 'Snow Grains';
    }
    // Rain showers: Slight, moderate, and violent
    else if (code >= 80 && code <= 82) {
      return 'Rain Showers';
    }
    // Snow showers slight and heavy
    else if (code >= 85 && code <= 86) {
      return 'Snow Showers';
    }
    // Thunderstorm: Slight or moderate
    else if (code >= 95 && code <= 99) {
      return 'Thunderstorm';
    }
    // Default fallback
    else {
      return 'Partly Cloudy';
    }
  }
}

