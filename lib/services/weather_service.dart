import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _openMeteoBaseUrl =
      'https://api.open-meteo.com/v1/forecast';
  static const String _nominatimUrl =
      'https://nominatim.openstreetmap.org/search';

  /// Helper to get coordinates from a city name using Nominatim
  Future<Map<String, double>?> getCoordinates(String location) async {
    try {
      final response = await http.get(
        Uri.parse('$_nominatimUrl?q=$location&format=json&limit=1'),
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lon': double.parse(data[0]['lon']),
          };
        }
      }
    } catch (e) {
      //print statements for error handling.
    }
    return null;
  }

  /// Get current weather for a location (by city name)
  Future<Map<String, dynamic>?> getCurrentWeather(String location) async {
    final coords = await getCoordinates(location);
    if (coords == null) return null;
    try {
      final url =
          '$_openMeteoBaseUrl?latitude=${coords['lat']}&longitude=${coords['lon']}&current_weather=true&timezone=auto';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['current_weather'];
      }
    } catch (e) {
      // Removed print statements for error handling.
    }
    return null;
  }

  /// Get hourly forecast for a location (up to 16 days)
  Future<List<Map<String, dynamic>>?> getHourlyForecast(
    String location, {
    int hours = 48,
  }) async {
    final coords = await getCoordinates(location);
    if (coords == null) return null;
    try {
      final url =
          '$_openMeteoBaseUrl?latitude=${coords['lat']}&longitude=${coords['lon']}&hourly=temperature_2m,precipitation,weathercode,humidity_2m,wind_speed_10m&forecast_days=16&timezone=auto';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final times = data['hourly']['time'] as List;
        final temps = data['hourly']['temperature_2m'] as List;
        final precs = data['hourly']['precipitation'] as List;
        final codes = data['hourly']['weathercode'] as List;
        final hums = data['hourly']['humidity_2m'] as List;
        final winds = data['hourly']['wind_speed_10m'] as List;
        List<Map<String, dynamic>> result = [];
        for (int i = 0; i < times.length && i < hours; i++) {
          result.add({
            'time': times[i],
            'temperature': temps[i],
            'precipitation': precs[i],
            'weathercode': codes[i],
            'humidity': hums[i],
            'wind_speed': winds[i],
          });
        }
        return result;
      }
    } catch (e) {
      // Error handling
    }
    return null;
  }

  /// Get daily forecast for a location (up to 16 days)
  Future<List<Map<String, dynamic>>?> getDailyForecast(
    String location, {
    int days = 14,
  }) async {
    final coords = await getCoordinates(location);
    if (coords == null) return null;
    try {
      final url =
          '$_openMeteoBaseUrl?latitude=${coords['lat']}&longitude=${coords['lon']}&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode,wind_speed_10m_max&forecast_days=16&timezone=auto';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final times = data['daily']['time'] as List;
        final tempMax = data['daily']['temperature_2m_max'] as List;
        final tempMin = data['daily']['temperature_2m_min'] as List;
        final precSum = data['daily']['precipitation_sum'] as List;
        final codes = data['daily']['weathercode'] as List;
        final windMax = data['daily']['wind_speed_10m_max'] as List;
        List<Map<String, dynamic>> result = [];
        for (int i = 0; i < times.length && i < days; i++) {
          result.add({
            'date': times[i],
            'temp_max': tempMax[i],
            'temp_min': tempMin[i],
            'precipitation_sum': precSum[i],
            'weathercode': codes[i],
            'wind_speed_max': windMax[i],
          });
        }
        return result;
      }
    } catch (e) {
      // Error handling
    }
    return null;
  }

  /// Get comprehensive weather data (current + hourly + daily)
  Future<Map<String, dynamic>?> getComprehensiveWeatherData(
    String location,
  ) async {
    try {
      final current = await getCurrentWeather(location);
      final hourly = await getHourlyForecast(location);
      final daily = await getDailyForecast(location);
      return {
        'current': current,
        'hourly': hourly,
        'daily': daily,
        'location': location,
        'fetched_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      // Error handling
    }
    return null;
  }

  /// Get current weather for the user's farm location (or current location if not provided)
  Future<Map<String, dynamic>?> getCurrentWeatherForUser({
    String? location,
  }) async {
    Map<String, double>? coords;
    if (location != null && location.trim().isNotEmpty) {
      coords = await getCoordinates(location);
      coords ??= await getCoordinates('Kampala, Uganda');
    } else {
      coords = await getCoordinates('Kampala, Uganda');
    }
    if (coords == null) return null;
    try {
      final url =
          '$_openMeteoBaseUrl?latitude=${coords['lat']}&longitude=${coords['lon']}&current_weather=true&timezone=auto';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['current_weather'];
      }
    } catch (e) {
      // Error handling
    }
    return null;
  }

  /// Get hourly forecast for the user's farm location (or current location if not provided)
  Future<List<Map<String, dynamic>>?> getHourlyForecastForUser({
    int hours = 48,
    String? location,
  }) async {
    Map<String, double>? coords;
    if (location != null && location.trim().isNotEmpty) {
      coords = await getCoordinates(location);
      coords ??= await getCoordinates('Kampala, Uganda');
    } else {
      coords = await getCoordinates('Kampala, Uganda');
    }
    if (coords == null) return null;
    try {
      final url =
          '$_openMeteoBaseUrl?latitude=${coords['lat']}&longitude=${coords['lon']}&hourly=temperature_2m,relative_humidity_2m,pressure_msl,cloudcover,visibility,precipitation,wind_speed_10m,weathercode&forecast_days=2&timezone=auto';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final times = data['hourly']['time'] as List;
        final temps = data['hourly']['temperature_2m'] as List;
        final hums = data['hourly']['relative_humidity_2m'] as List;
        final press = data['hourly']['pressure_msl'] as List;
        final clouds = data['hourly']['cloudcover'] as List;
        final vis = data['hourly']['visibility'] as List;
        final precs = data['hourly']['precipitation'] as List;
        final winds = data['hourly']['wind_speed_10m'] as List;
        final codes = data['hourly']['weathercode'] as List;
        List<Map<String, dynamic>> result = [];
        for (int i = 0; i < times.length && i < hours; i++) {
          result.add({
            'time': times[i],
            'temperature': temps[i],
            'humidity': hums[i],
            'pressure': press[i],
            'cloudcover': clouds[i],
            'visibility': vis[i],
            'precipitation': precs[i],
            'wind_speed': winds[i],
            'weathercode': codes[i],
          });
        }
        return result;
      }
    } catch (e) {
      // Error handling
    }
    return null;
  }

  /// Get daily forecast for the user's farm location (or current location if not provided)
  Future<List<Map<String, dynamic>>?> getDailyForecastForUser({
    int days = 14,
    String? location,
  }) async {
    Map<String, double>? coords;
    if (location != null && location.trim().isNotEmpty) {
      coords = await getCoordinates(location);
      coords ??= await getCoordinates('Kampala, Uganda');
    } else {
      coords = await getCoordinates('Kampala, Uganda');
    }
    if (coords == null) return null;
    try {
      final url =
          '$_openMeteoBaseUrl?latitude=${coords['lat']}&longitude=${coords['lon']}&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode,wind_speed_10m_max&forecast_days=16&timezone=auto';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final times = data['daily']['time'] as List;
        final tempMax = data['daily']['temperature_2m_max'] as List;
        final tempMin = data['daily']['temperature_2m_min'] as List;
        final precSum = data['daily']['precipitation_sum'] as List;
        final codes = data['daily']['weathercode'] as List;
        final windMax = data['daily']['wind_speed_10m_max'] as List;
        List<Map<String, dynamic>> result = [];
        for (int i = 0; i < times.length && i < days; i++) {
          result.add({
            'date': times[i],
            'temp_max': tempMax[i],
            'temp_min': tempMin[i],
            'precipitation_sum': precSum[i],
            'weathercode': codes[i],
            'wind_speed_max': windMax[i],
          });
        }
        return result;
      }
    } catch (e) {
      // Removed print statements for error handling.
    }
    return null;
  }

  /// Get current weather for a location by coordinates (lat, lon)
  Future<Map<String, dynamic>?> getCurrentWeatherByCoords(
    double lat,
    double lon,
  ) async {
    final url =
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&timezone=auto';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['current_weather'];
      }
    } catch (e) {
      //Error handling
    }
    return null;
  }
}
