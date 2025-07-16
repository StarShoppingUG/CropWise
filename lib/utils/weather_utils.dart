import 'package:flutter/material.dart';

class WeatherUtils {
  static IconData getWeatherIcon(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('cloud')) {
      return Icons.cloud;
    } else if (desc.contains('clear') || desc.contains('sun')) {
      return Icons.wb_sunny;
    } else if (desc.contains('rain')) {
      return Icons.umbrella;
    } else if (desc.contains('fog')) {
      return Icons.foggy;
    } else if (desc.contains('drizzle')) {
      return Icons.grain;
    } else if (desc.contains('freezing')) {
      return Icons.ac_unit;
    } else if (desc.contains('snow')) {
      return Icons.ac_unit;
    } else if (desc.contains('thunderstorm')) {
      return Icons.flash_on;
    } else {
      return Icons.help_outline;
    }
  }

  static String getWeatherDescription(int code) {
    if (code == 0) return 'Clear';
    if (code == 1 || code == 2 || code == 3) return 'Cloudy';
    if (code == 45 || code == 48) return 'Fog';
    if (code == 51 || code == 53 || code == 55) return 'Drizzle';
    if (code == 56 || code == 57) return 'Freezing Drizzle';
    if (code == 61 || code == 63 || code == 65) return 'Rain';
    if (code == 66 || code == 67) return 'Freezing Rain';
    if (code == 71 || code == 73 || code == 75) return 'Snow';
    if (code == 77) return 'Snow';
    if (code == 80 || code == 81 || code == 82) return 'Rain';
    if (code == 85 || code == 86) return 'Snow';
    if (code == 95) return 'Thunderstorm';
    if (code == 96 || code == 99) return 'Thunderstorm';
    return 'Unknown';
  }
} 