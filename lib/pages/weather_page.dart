import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/app_gradients.dart';
import '../widgets/glass_card.dart';
import '../../services/weather_service.dart';
import '../../services/ai_service.dart';
import '../../services/user_service.dart';
import '../utils/weather_utils.dart';
import 'package:provider/provider.dart';
import '../models/location_provider.dart';
import 'package:intl/intl.dart';

//Format smart recommendations
Map<String, dynamic> parseRecommendation(String suggestion) {
  final lines = suggestion.split('\n');
  String headline = '';
  List<String> actions = [];
  String? tip;
  for (final line in lines) {
    if (headline.isEmpty && line.trim().isNotEmpty) {
      headline = line.trim();
    } else if (line.trim().startsWith('-')) {
      actions.add(line.trim().substring(1).trim());
    } else if (line.trim().toLowerCase().startsWith('tip:')) {
      tip = line.trim().substring(4).trim();
    }
  }
  // If no actions, treat headline as action
  if (actions.isEmpty && headline.isNotEmpty) {
    actions.add(headline);
    headline = '';
  }
  // Fallback for empty/short responses
  if (actions.isEmpty && (tip == null || tip.isEmpty)) {
    actions.add('No detailed recommendations available at this time.');
  }
  return {'headline': headline, 'actions': actions, 'tip': tip};
}

// Displays weather information and AI farming recommendations.
class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final WeatherService _weatherService = WeatherService();
  final AIService _aiService = AIService();
  final UserService _userService = UserService();
  String _currentLocation = '';
  String? _lastLocation;
  bool _isLoading = true;
  bool _showForecast = false;
  Map<String, dynamic>? _currentWeather;
  List<Map<String, dynamic>>? _forecast;
  List<Map<String, dynamic>>? _hourlyForecast;
  List<String>? _aiSuggestions;
  bool _loadingSuggestions = true;
  List<String> _userPrimaryCrops = [];
  String _cacheStatus = '';
  String? _lastFetchedHourStr;

  @override
  void initState() {
    super.initState();
    _loadLocationAndData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = Provider.of<LocationProvider>(context).location;
    if (location.isNotEmpty && location != _lastLocation) {
      _lastLocation = location;
      _currentLocation = location;
      _loadWeatherData(forceRefresh: true);
    }
  }

  Future<void> _loadLocationAndData() async {
    // Fetch user profile to get farm location
    final userProfile = await _userService.getUserProfile();
    String? locationName = userProfile?['location'];
    setState(() {
      _currentLocation = locationName ?? '';
    });
    await _loadUserData();
    await _loadWeatherData();
  }

  Future<void> _loadUserData() async {
    try {
      final userProfile = await _userService.getUserProfile();
      if (userProfile != null) {
        setState(() {
          _userPrimaryCrops = List<String>.from(
            userProfile['primaryCrops'] ?? [],
          );
        });
      }
      // Check cached recommendations after loading user data
      _checkAndLoadCachedRecommendations();
    } catch (e) {
      // Still check cached recommendations even if user data fails
      _checkAndLoadCachedRecommendations();
    }
  }

  String _formatCacheAge(int ageMs) {
    final hours = ageMs ~/ (60 * 60 * 1000);
    final minutes = (ageMs % (60 * 60 * 1000)) ~/ (60 * 1000);

    if (hours > 0) {
      return '${hours}h ${minutes}m ago';
    } else {
      return '${minutes}m ago';
    }
  }

  void _checkAndLoadCachedRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTime = prefs.getInt('ai_suggestions_cache_time') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final cacheAge = currentTime - cachedTime;
    final cacheValid = cacheAge < 24 * 60 * 60 * 1000; // 24 hours

    if (cacheValid) {
      final cachedSuggestions =
          prefs.getStringList('ai_suggestions_cache') ?? [];
      if (cachedSuggestions.isNotEmpty) {
        setState(() {
          _aiSuggestions = cachedSuggestions;
          _cacheStatus =
              'Using cached recommendations (${_formatCacheAge(cacheAge)})';
          _loadingSuggestions = false;
        });
        return;
      }
    }

    // No valid cache, fetch new suggestions with real weather data
    if (_currentWeather != null) {
      _fetchAISuggestions();
    } else {
      // No weather data available, stop loading
      setState(() {
        _loadingSuggestions = false;
        _aiSuggestions = [];
        _cacheStatus = 'No weather data available';
      });
    }
  }

  Future<void> _cacheRecommendations(List<String> recommendations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      await prefs.setStringList('ai_suggestions_cache', recommendations);
      await prefs.setInt('ai_suggestions_cache_time', currentTime);

      setState(() {
        _cacheStatus = 'Fresh from AI';
      });
    } catch (e) {}
  }

  Future<void> _loadWeatherData({bool forceRefresh = false}) async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final currentWeather = await _weatherService.getCurrentWeatherForUser(
        location: _currentLocation,
      );
      final forecastRaw = await _weatherService.getDailyForecastForUser(
        days: 14,
        location: _currentLocation,
      );
      final hourlyForecastRaw = await _weatherService.getHourlyForecastForUser(
        hours: 24,
        location: _currentLocation,
      );

      final forecast = (forecastRaw ?? []).cast<Map<String, dynamic>>();
      final hourlyForecastRawData =
          (hourlyForecastRaw ?? []).cast<Map<String, dynamic>>();
      final hourlyForecast = _convertHourlyForecastToDisplayFormat(
        hourlyForecastRawData,
      );

      if (!mounted) return;
      setState(() {
        _currentWeather = currentWeather;
        _forecast = forecast;
        _hourlyForecast = hourlyForecast;
        _isLoading = false;
      });

      // After weather data is loaded, determine current hour's data and fetch AI suggestions
      final now = DateTime.now();
      final todayStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final todayHourlyForecast =
          hourlyForecast
              .where((h) => h['time'].toString().startsWith(todayStr))
              .toList();
      Map<String, dynamic>? currentHourData;
      String? nowHourStr;
      if (todayHourlyForecast.isNotEmpty) {
        nowHourStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:00';
        currentHourData = todayHourlyForecast.firstWhere(
          (h) => h['time'] == nowHourStr,
          orElse: () => todayHourlyForecast[0],
        );
      }
      // Only fetch if the hour changed or no cache exists for this hour
      if (nowHourStr != null && _lastFetchedHourStr != nowHourStr) {
        _lastFetchedHourStr = nowHourStr;
        await _fetchAISuggestionsForCurrentHour(currentHourData);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // No weather data available, stop loading
      setState(() {
        _loadingSuggestions = false;
        _aiSuggestions = [];
      });
    }
  }

  Future<void> _fetchAISuggestions({bool forceIgnoreCache = false}) async {
    setState(() {
      _loadingSuggestions = true;
    });

    try {
      // Get the primary crop for AI recommendations
      String cropForAI = 'General farming';
      if (_userPrimaryCrops.isNotEmpty) {
        // Use the first primary crop, or combine multiple crops
        if (_userPrimaryCrops.length == 1) {
          cropForAI = _userPrimaryCrops.first;
        } else {
          cropForAI = _userPrimaryCrops.join(', ');
        }
      }

      // Use real current weather data instead of hardcoded forecast
      Map<String, dynamic> weatherData = {
        'temperature': 00.0, // Default fallback
        'humidity': 00.0,
        'wind_speed': 0.0,
        'pressure': 0.0,
        'main': 'unknown',
        'rain': 0.0,
      };

      // Get real weather data if available
      if (_currentWeather != null) {
        final main = _currentWeather!['main'];
        final wind = _currentWeather!['wind'];
        final rain = _currentWeather!['rain'];
        final weather = _currentWeather!['weather']?[0];

        weatherData = {
          'temperature': main?['temp']?.toDouble() ?? 25.0,
          'humidity': main?['humidity']?.toDouble() ?? 65.0,
          'pressure': main?['pressure']?.toDouble() ?? 1013.0,
          'wind_speed': wind?['speed']?.toDouble() ?? 8.0,
          'wind_direction': wind?['deg']?.toDouble(),
          'main': weather?['main']?.toString() ?? 'Clear',
          'description': weather?['description']?.toString() ?? 'clear sky',
          'rain': rain?['1h']?.toDouble() ?? 0.0,
          'visibility': _currentWeather!['visibility']?.toDouble(),
          'clouds': _currentWeather!['clouds']?['all']?.toDouble(),
        };
      } else {}

      final aiSuggestions = await _aiService.generateWeatherAdvice(
        crop: cropForAI,
        weatherData: weatherData,
        location: _currentLocation,
      );

      if (mounted) {
        setState(() {
          _aiSuggestions = aiSuggestions;
          _loadingSuggestions = false;
        });

        // Cache the recommendations only if not force ignoring cache
        if (aiSuggestions.isNotEmpty && !forceIgnoreCache) {
          _cacheRecommendations(aiSuggestions);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiSuggestions = [];
          _loadingSuggestions = false;
          _cacheStatus = 'Error: Unable to fetch recommendations';
        });
      }
    }
  }

  Future<void> _fetchAISuggestionsForCurrentHour(
    Map<String, dynamic>? currentHourData,
  ) async {
    setState(() {
      _loadingSuggestions = true;
    });
    try {
      // Always use user's primary crops, fallback to 'General farming'
      String cropForAI = 'General farming';
      if (_userPrimaryCrops.isNotEmpty) {
        cropForAI = _userPrimaryCrops.join(', ');
      }
      if (currentHourData == null) {
        setState(() {
          _aiSuggestions = [];
          _loadingSuggestions = false;
        });
        return;
      }
      final now = DateTime.now();
      final hourKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:00';
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString('ai_suggestions_hourly_cache') ?? '{}';
      final cacheMap = Map<String, dynamic>.from(json.decode(cacheData));
      final cacheTimes =
          prefs.getString('ai_suggestions_hourly_cache_times') ?? '{}';
      final cacheTimesMap = Map<String, dynamic>.from(json.decode(cacheTimes));
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final cacheValidMs = 24 * 60 * 60 * 1000; // 24 hours
      // Clean up old cache entries
      final keysToRemove = <String>[];
      cacheTimesMap.forEach((key, value) {
        if (currentTime - (value as int) > cacheValidMs) {
          keysToRemove.add(key);
        }
      });
      for (final key in keysToRemove) {
        cacheMap.remove(key);
        cacheTimesMap.remove(key);
      }
      // Check if we have valid cache for this hour (strictly hourly)
      if (cacheMap.containsKey(hourKey) && cacheTimesMap.containsKey(hourKey)) {
        final cacheTimestamp = cacheTimesMap[hourKey] as int;
        final cacheDateTime = DateTime.fromMillisecondsSinceEpoch(
          cacheTimestamp,
        );
        // Only use cache if it's from the same hour as now
        if (cacheDateTime.year == now.year &&
            cacheDateTime.month == now.month &&
            cacheDateTime.day == now.day &&
            cacheDateTime.hour == now.hour) {
          final cacheAge = currentTime - cacheTimestamp;
          final cachedSuggestions = List<String>.from(cacheMap[hourKey]);
          setState(() {
            _aiSuggestions = cachedSuggestions;
            _loadingSuggestions = false;
            _cacheStatus =
                'Using cached recommendations (${_formatCacheAge(cacheAge)})';
          });
          // Save cleaned cache
          await prefs.setString(
            'ai_suggestions_hourly_cache',
            json.encode(cacheMap),
          );
          await prefs.setString(
            'ai_suggestions_hourly_cache_times',
            json.encode(cacheTimesMap),
          );
          return;
        }
      }
      // No valid cache, fetch from AI
      final weatherData = {
        'temperature': currentHourData['temperature']?.toDouble() ?? 25.0,
        'humidity': currentHourData['humidity']?.toDouble() ?? 65.0,
        'pressure': currentHourData['pressure']?.toDouble() ?? 1013.0,
        'wind_speed': currentHourData['wind_speed']?.toDouble() ?? 8.0,
        'wind_direction': currentHourData['wind_direction']?.toDouble(),
        'main':
            currentHourData['weathercode'] != null
                ? WeatherUtils.getWeatherDescription(
                  currentHourData['weathercode'],
                )
                : 'Clear',
        'description':
            currentHourData['weathercode'] != null
                ? WeatherUtils.getWeatherDescription(
                  currentHourData['weathercode'],
                )
                : 'clear sky',
        'rain': currentHourData['rain']?.toDouble() ?? 0.0,
        'visibility': currentHourData['visibility']?.toDouble(),
        'clouds': currentHourData['cloudcover']?.toDouble(),
      };
      final aiSuggestions = await _aiService.generateWeatherAdvice(
        crop: cropForAI,
        weatherData: weatherData,
        location: _currentLocation,
      );
      // Cache the result
      cacheMap[hourKey] = aiSuggestions;
      cacheTimesMap[hourKey] = currentTime;
      await prefs.setString(
        'ai_suggestions_hourly_cache',
        json.encode(cacheMap),
      );
      await prefs.setString(
        'ai_suggestions_hourly_cache_times',
        json.encode(cacheTimesMap),
      );
      if (mounted) {
        setState(() {
          _aiSuggestions = aiSuggestions;
          _loadingSuggestions = false;
          _cacheStatus = 'Fresh from AI';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiSuggestions = [];
          _loadingSuggestions = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _convertForecastToDisplayFormat(
    List<Map<String, dynamic>> forecast,
  ) {
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < forecast.length && i < 14; i++) {
      final dayData = forecast[i];
      final temp = dayData['temp_max']?.toDouble() ?? 25.0;
      final rain = dayData['precipitation_sum']?.toDouble() ?? 0.0;
      final humidity = dayData['humidity']?.toDouble() ?? 65.0;
      final windSpeed = dayData['wind_speed_max']?.toDouble() ?? 8.0;
      final description =
          dayData['weathercode'] != null
              ? WeatherUtils.getWeatherDescription(dayData['weathercode'])
              : 'Clear';
      String? dateStr = dayData['date'];
      if (dateStr == null && dayData['time'] != null) {
        dateStr = dayData['time'].toString().substring(0, 10);
      }
      String? formattedDate;
      String? weekday;
      if (dateStr != null) {
        try {
          final date = DateTime.parse(dateStr);
          formattedDate = DateFormat('E, dd MMM').format(date);
          weekday = DateFormat('E').format(date);
        } catch (e) {
          formattedDate = dateStr;
          weekday = '';
        }
      }
      result.add({
        'day': weekday ?? '',
        'date': formattedDate,
        'temp': '${temp.round()}°C',
        'rain': rain > 5 ? 'Yes' : 'No',
        'rainIntensity':
            rain > 15
                ? 'Heavy'
                : rain > 5
                ? 'Moderate'
                : 'None',
        'windSpeed': windSpeed.round(),
        'humidity': humidity.round(),
        'uvIndex': (temp / 4).round().clamp(1, 10),
        'icon': WeatherUtils.getWeatherIcon(
          description,
          isNight:
              (() {
                DateTime? dt;
                if (dayData['date'] != null) {
                  try {
                    dt = DateTime.parse(dayData['date']);
                  } catch (_) {}
                }
                if (dt == null && dayData['time'] != null) {
                  try {
                    dt = DateTime.parse(dayData['time']);
                  } catch (_) {}
                }
                if (dt != null) {
                  return dt.hour < 6 || dt.hour >= 18;
                }
                return DateTime.now().hour < 6 || DateTime.now().hour >= 18;
              })(),
        ),
        'desc': description,
      });
    }
    return result;
  }

  List<Map<String, dynamic>> _convertHourlyForecastToDisplayFormat(
    List<Map<String, dynamic>> hourlyForecast,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final hour in hourlyForecast) {
      final time = hour['time'] as String;
      final temperature = hour['temperature']?.toDouble() ?? 25.0;
      final humidity = hour['humidity']?.toDouble() ?? 65.0;
      final pressure = hour['pressure']?.toDouble() ?? 1013.0;
      final cloudcover = hour['cloudcover']?.toDouble() ?? 0.0;
      final visibility = hour['visibility']?.toDouble() ?? 10000.0;
      final precipitation = hour['precipitation']?.toDouble() ?? 0.0;
      final windSpeed = hour['wind_speed']?.toDouble() ?? 8.0;
      final weathercode = hour['weathercode'] as int?;

      // Get weather description and determine if it's raining
      final description =
          weathercode != null
              ? WeatherUtils.getWeatherDescription(weathercode)
              : 'Clear';
      final isRain = description.toLowerCase().contains('rain');

      bool isNight = false;
      if (hour['time'] is String && (hour['time'] as String).length >= 13) {
        try {
          final hourInt = int.parse((hour['time'] as String).substring(11, 13));
          isNight = hourInt < 6 || hourInt >= 18;
        } catch (_) {
          isNight = DateTime.now().hour < 6 || DateTime.now().hour >= 18;
        }
      } else {
        isNight = DateTime.now().hour < 6 || DateTime.now().hour >= 18;
      }

      result.add({
        'time': time,
        'temperature': temperature,
        'humidity': humidity,
        'pressure': pressure,
        'cloudcover': cloudcover,
        'visibility': visibility,
        'precipitation': precipitation,
        'wind_speed': windSpeed,
        'weathercode': weathercode,
        'description': description,
        'isRain': isRain,
        'icon': WeatherUtils.getWeatherIcon(description, isNight: isNight),
      });
    }
    return result;
  }

  Widget _buildForecastSection(
    BuildContext context,
    List<Map<String, dynamic>> forecast,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final forecastData =
        _forecast != null ? _convertForecastToDisplayFormat(_forecast!) : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '14-Day Forecast',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _showForecast = !_showForecast;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showForecast
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showForecast ? 'Hide' : 'Show',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_showForecast)
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: forecastData.length,
              itemBuilder: (context, index) {
                final day = forecastData[index];
                final isRain = day['rain'] == 'Yes';
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: _DailyForecastCard(
                    day: day,
                    isRain: isRain,
                    colorScheme: colorScheme,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Robust filtering for 14-day forecast
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final forecast =
        (_forecast ?? <Map<String, dynamic>>[]).where((dayData) {
          String? dateStr = dayData['date'];
          // Fallback to 'time' if 'date' is missing
          if (dateStr == null && dayData['time'] != null) {
            final timeStr = dayData['time'].toString();
            dateStr = timeStr.length >= 10 ? timeStr.substring(0, 10) : null;
          }
          if (dateStr == null) return false;
          try {
            final date = DateTime.parse(dateStr);
            final forecastDay = DateTime(date.year, date.month, date.day);
            return !forecastDay.isBefore(today);
          } catch (e) {
            return false;
          }
        }).toList();
    final colorScheme = Theme.of(context).colorScheme;
    final hourlyForecast = _hourlyForecast ?? <Map<String, dynamic>>[];

    // Get the current hour's data from hourlyForecast
    Map<String, dynamic>? currentHourData;
    if (hourlyForecast.isNotEmpty) {
      final nowHourStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:00';
      currentHourData = hourlyForecast.firstWhere(
        (h) => h['time'] == nowHourStr,
        orElse: () => hourlyForecast[0],
      );
    }

    // If weather data is missing, show a friendly message
    if (_currentWeather == null || currentHourData == null) {
      return Container(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 48, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Weather data unavailable.',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your internet connection or try again later.',
                  style: TextStyle(
                    color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed:
                      _isLoading
                          ? null
                          : () async {
                            setState(() {
                              _isLoading = true;
                            });
                            await _loadWeatherData(forceRefresh: true);
                          },
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary.withAlpha(
                      (0.85 * 255).toInt(),
                    ),
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Daily (Hourly) Forecast for Today
    Widget hourlyForecastWidget;
    if (hourlyForecast.isEmpty) {
      hourlyForecastWidget = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            'No hourly forecast data available.',
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
              fontSize: 14,
            ),
          ),
        ),
      );
    } else {
      hourlyForecastWidget = SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hourlyForecast.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, idx) {
            final hour = hourlyForecast[idx];
            return _HourlyForecastCard(hour: hour, colorScheme: colorScheme);
          },
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          body: Container(
            decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          18.0,
                          24.0,
                          18.0,
                          40.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Today Weather Card
                            (() {
                              final desc = currentHourData?['weathercode'];
                              final isRain =
                                  (desc != null &&
                                      WeatherUtils.getWeatherDescription(
                                        desc,
                                      ).toLowerCase().contains('rain'));
                              return GlassCard(
                                borderRadius: 20,
                                padding: const EdgeInsets.all(16),
                                gradient: LinearGradient(
                                  colors: [
                                    isRain
                                        ? colorScheme.secondary.withAlpha(
                                          (0.2 * 255).toInt(),
                                        )
                                        : colorScheme.primary.withAlpha(
                                          (0.2 * 255).toInt(),
                                        ),
                                    colorScheme.surface.withAlpha(
                                      (0.1 * 255).toInt(),
                                    ),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderColor:
                                    isRain
                                        ? colorScheme.secondary.withAlpha(
                                          (0.3 * 255).toInt(),
                                        )
                                        : colorScheme.primary.withAlpha(
                                          (0.3 * 255).toInt(),
                                        ),
                                borderWidth: 1.5,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      (0.04 * 255).toInt(),
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            colorScheme.primary.withAlpha(
                                              (0.3 * 255).toInt(),
                                            ),
                                            colorScheme.primary,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 32,
                                        backgroundColor: Colors.transparent,
                                        child: Icon(
                                          WeatherUtils.getWeatherIcon(
                                            WeatherUtils.getWeatherDescription(
                                              currentHourData?['weathercode'],
                                            ),
                                            isNight:
                                                DateTime.now().hour < 6 ||
                                                DateTime.now().hour >= 18,
                                          ),
                                          color: colorScheme.onPrimary,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Today in $_currentLocation',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                                  maxLines: 2,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${currentHourData?['temperature'] != null ? '${currentHourData!['temperature'].round()}°C' : 'N/A'}, '
                                            '${currentHourData?['weathercode'] != null ? WeatherUtils.getWeatherDescription(currentHourData!['weathercode']) : 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: colorScheme.onSurface
                                                  .withAlpha(
                                                    (0.7 * 255).toInt(),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _WeatherDetail(
                                                icon: Icons.water_drop,
                                                value:
                                                    currentHourData?['humidity'] !=
                                                            null
                                                        ? '${currentHourData!['humidity'].round()}%'
                                                        : 'N/A',
                                                label: 'Humidity',
                                                colorScheme: colorScheme,
                                              ),
                                              const SizedBox(width: 16),
                                              _WeatherDetail(
                                                icon: Icons.air,
                                                value:
                                                    currentHourData?['wind_speed'] !=
                                                            null
                                                        ? '${currentHourData!['wind_speed'].round()} m/s'
                                                        : 'N/A',
                                                label: 'Wind',
                                                colorScheme: colorScheme,
                                              ),
                                              const SizedBox(width: 16),
                                              _WeatherDetail(
                                                icon: Icons.speed,
                                                value:
                                                    currentHourData?['pressure'] !=
                                                            null
                                                        ? '${currentHourData!['pressure'].round()} hPa'
                                                        : 'N/A',
                                                label: 'Pressure',
                                                colorScheme: colorScheme,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _WeatherDetail(
                                                icon: Icons.visibility,
                                                value:
                                                    currentHourData?['visibility'] !=
                                                            null
                                                        ? '${(currentHourData!['visibility'] / 1000).toStringAsFixed(1)} km'
                                                        : 'N/A',
                                                label: 'Visibility',
                                                colorScheme: colorScheme,
                                              ),
                                              const SizedBox(width: 16),
                                              _WeatherDetail(
                                                icon: Icons.cloud,
                                                value:
                                                    currentHourData?['cloudcover'] !=
                                                            null
                                                        ? '${currentHourData!['cloudcover'].round()}%'
                                                        : 'N/A',
                                                label: 'Clouds',
                                                colorScheme: colorScheme,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })(),
                            const SizedBox(height: 12),
                            // Daily (Hourly) Forecast for Today
                            Text(
                              'Today\'s Hourly Forecast',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            hourlyForecastWidget,
                            const SizedBox(height: 20),
                            // Toggle 14-Day Forecast
                            _forecast == null || _forecast!.isEmpty
                                ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24.0,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'No forecast data available.',
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withAlpha(
                                          (0.7 * 255).toInt(),
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                                : _buildForecastSection(context, forecast),
                            const SizedBox(height: 24),
                            // Enhanced Suggestions Card
                            GlassCard(
                              borderRadius: 24,
                              padding: const EdgeInsets.all(24),
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.secondary.withAlpha(
                                    (0.15 * 255).toInt(),
                                  ),
                                  colorScheme.secondary.withAlpha(
                                    (0.05 * 255).toInt(),
                                  ),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderColor: colorScheme.secondary.withAlpha(
                                (0.2 * 255).toInt(),
                              ),
                              borderWidth: 1.5,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(
                                    (0.06 * 255).toInt(),
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              colorScheme.secondary.withAlpha(
                                                (0.3 * 255).toInt(),
                                              ),
                                              colorScheme.secondary,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.transparent,
                                          child: Icon(
                                            Icons.lightbulb_outline,
                                            color: colorScheme.onSecondary,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Smart Recommendations',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            if (_userPrimaryCrops.isNotEmpty)
                                              Text(
                                                'Based on: ${_userPrimaryCrops.join(', ')}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colorScheme.onSurface
                                                      .withAlpha(
                                                        (0.6 * 255).toInt(),
                                                      ),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              )
                                            else
                                              Text(
                                                'Based on: General farming',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colorScheme.onSurface
                                                      .withAlpha(
                                                        (0.6 * 255).toInt(),
                                                      ),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (_loadingSuggestions)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ),
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  if (_aiSuggestions != null &&
                                      _aiSuggestions!.isNotEmpty)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (
                                          int i = 0;
                                          i < _aiSuggestions!.length;
                                          i++
                                        ) ...[
                                          if (i > 0)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 1.0,
                                                  ),
                                              child: Divider(
                                                color: colorScheme.onSurface
                                                    .withAlpha(
                                                      (0.08 * 255).toInt(),
                                                    ),
                                                thickness: 1,
                                              ),
                                            ),
                                          _StyledRecommendationBlock(
                                            suggestion: _aiSuggestions![i],
                                            colorScheme: colorScheme,
                                          ),
                                        ],
                                      ],
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6.0,
                                      ),
                                      child: Text(
                                        'No recommendations available.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurface
                                              .withAlpha((0.7 * 255).toInt()),
                                        ),
                                      ),
                                    ),
                                  if (_aiSuggestions != null &&
                                      _aiSuggestions!.isNotEmpty &&
                                      _cacheStatus.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3.0),
                                      child: Text(
                                        _cacheStatus,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurface
                                              .withAlpha((0.5 * 255).toInt()),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed:
                _isLoading
                    ? null
                    : () async {
                      setState(() {
                        _isLoading = true;
                      });
                      await _loadWeatherData(forceRefresh: true);
                    },
            backgroundColor: colorScheme.primary,
            tooltip: 'Refresh Weather',
            child:
                _isLoading
                    ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onPrimary,
                      ),
                      strokeWidth: 2,
                    )
                    : Icon(Icons.refresh, color: colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}

class _DailyForecastCard extends StatelessWidget {
  final Map<String, dynamic> day;
  final bool isRain;
  final ColorScheme colorScheme;

  const _DailyForecastCard({
    required this.day,
    required this.isRain,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        gradient: LinearGradient(
          colors: [
            isRain
                ? colorScheme.secondary.withAlpha((0.2 * 255).toInt())
                : colorScheme.primary.withAlpha((0.2 * 255).toInt()),
            colorScheme.surface.withAlpha((0.1 * 255).toInt()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderColor:
            isRain
                ? colorScheme.secondary.withAlpha((0.3 * 255).toInt())
                : colorScheme.primary.withAlpha((0.3 * 255).toInt()),
        borderWidth: 1.5,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              day['icon'] as IconData,
              color: isRain ? colorScheme.secondary : colorScheme.primary,
              size: 28,
            ),
            const SizedBox(height: 8),
            if (day['date'] != null)
              Text(
                day['date'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              day['temp'] as String,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day['desc'] as String,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyForecastCard extends StatelessWidget {
  final Map<String, dynamic> hour;
  final ColorScheme colorScheme;

  const _HourlyForecastCard({required this.hour, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final time = hour['time'];
    final temp = hour['temperature'];
    final wind = hour['wind_speed'];
    final humidity = hour['humidity'];
    final cloudcover = hour['cloudcover'];
    final isRain = hour['isRain'] ?? false;
    return SizedBox(
      width: 140,
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        gradient: LinearGradient(
          colors: [
            isRain
                ? colorScheme.secondary.withAlpha((0.2 * 255).toInt())
                : colorScheme.primary.withAlpha((0.2 * 255).toInt()),
            colorScheme.surface.withAlpha((0.1 * 255).toInt()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderColor:
            isRain
                ? colorScheme.secondary.withAlpha((0.3 * 255).toInt())
                : colorScheme.primary.withAlpha((0.3 * 255).toInt()),
        borderWidth: 1.5,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              hour['icon'] as IconData,
              size: 28,
              color: isRain ? colorScheme.secondary : colorScheme.primary,
            ),
            const SizedBox(height: 2),
            Text(
              time.substring(11, 16),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${temp.round()}°C',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              hour['description'] as String,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.air, size: 12, color: colorScheme.primary),
                    const SizedBox(width: 2),
                    Text(
                      '${wind.round()} m/s',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.water_drop,
                      size: 12,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${humidity.round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud, size: 12, color: colorScheme.primary),
                    const SizedBox(width: 2),
                    Text(
                      '${cloudcover.round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherDetail extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme colorScheme;

  const _WeatherDetail({
    required this.icon,
    required this.value,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurface.withAlpha((0.5 * 255).toInt()),
          ),
        ),
      ],
    );
  }
}

//Style each recommendation block
class _StyledRecommendationBlock extends StatelessWidget {
  final String suggestion;
  final ColorScheme colorScheme;
  const _StyledRecommendationBlock({
    required this.suggestion,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = parseRecommendation(suggestion);
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parsed['headline'] != null &&
              parsed['headline'] != 'Recommendation')
            Text(
              parsed['headline'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          if (parsed['actions'] != null &&
              (parsed['actions'] as List).isNotEmpty)
            Padding(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final action in parsed['actions'])
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 15)),
                        Expanded(
                          child: Text(
                            action,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha(
                                (0.85 * 255).toInt(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          if (parsed['tip'] != null && (parsed['tip'] as String).isNotEmpty)
            Padding(
              padding: EdgeInsets.zero,
              child: Text(
                '💡 ${parsed['tip']}',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
