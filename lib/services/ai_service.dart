import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../secrets.dart';

class AIService {
  /// Generate farming recommendations using free AI
  Future<List<String>> generateFarmingRecommendations({
    required String crop,
    required String goal,
    required List<Map<String, dynamic>> weatherData,
    required String location,
  }) async {
    try {
      final recommendations = await _generateWithCohere(
        crop: crop,
        goal: goal,
        weatherData: weatherData,
        location: location,
      );
      return recommendations;
    } catch (e) {
      return [];
    }
  }

  /// Generate daily farming plan using AI
  Future<List<Map<String, dynamic>>> generateDailyPlan({
    required String crop,
    required String goal,
    required List<Map<String, dynamic>> weatherData,
    required String location,
  }) async {
    try {
      final plan = await _generateDailyPlanWithCohere(
        crop: crop,
        goal: goal,
        weatherData: weatherData,
        location: location,
      );
      return plan;
    } catch (e) {
      return [];
    }
  }

  /// Generate weather-based farming advice using AI
  Future<List<String>> generateWeatherAdvice({
    required String crop,
    required Map<String, dynamic> weatherData,
    required String location,
  }) async {
    try {
      final advice = await _generateWeatherAdviceWithCohere(
        crop: crop,
        weatherData: weatherData,
        location: location,
      );
      return advice;
    } catch (e) {
      return [];
    }
  }

  /// Generate a continuation plan for the next 14 days, starting from lastDay+1, using previous plan context
  Future<List<Map<String, dynamic>>> generateContinuationPlan({
    required String crop,
    required String goal,
    required String location,
    required int lastDay,
    required List<Map<String, dynamic>> previousActivities,
    required List<Map<String, dynamic>> weatherData,
  }) async {
    try {
      // Summarize previous activities for the prompt
      final prevSummary = previousActivities
          .map((day) {
            final title = day['title'] ?? '';
            final tasks = (day['tasks'] as List?)?.join('; ') ?? '';
            return '${title.isNotEmpty ? title + ': ' : ''}$tasks';
          })
          .join('\n');
      final weatherSummary = weatherData
          .asMap()
          .entries
          .map((entry) {
            final i = entry.key;
            final day = entry.value;
            final temp = day['temp_max'] ?? day['temperature'] ?? 'N/A';
            final rain = day['precipitation_sum'] ?? day['rain'] ?? 'N/A';
            final desc = day['desc'] ?? day['description'] ?? 'N/A';
            return 'Day ${lastDay + i + 1}: $desc, Temp: $temp°C, Rain: $rain mm';
          })
          .join('\n');
      final prompt = '''
The full growing cycle for $crop in $location is estimated to be much longer than 14 days.

Here are the previous activities (Days 1-$lastDay):
$prevSummary

Based on the previous tasks, determine the current stage of the crop.

Now, generate a detailed plan for the next 14 days, starting from Day ${lastDay + 1}. Only include harvest or post-harvest if the crop is ready, otherwise continue with the next logical activities. Do not repeat previous activities.

14-day Weather Forecast for the next 14 days:
$weatherSummary

Format:
Day ${lastDay + 1}: [Title]
- Task 1
- Task 2
Notes: [Additional notes or considerations]

Continue for each day up to Day ${lastDay + 14}. Do not skip any days; if a day has no tasks, state so explicitly.
''';
      final response = await http.post(
        Uri.parse('https://api.cohere.ai/v1/generate'),
        headers: {
          'Authorization': 'Bearer $cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'command',
          'prompt': prompt,
          'max_tokens': 1200,
          'temperature': 0.7,
          'k': 0,
          'stop_sequences': [],
          'return_likelihoods': 'NONE',
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['generations'][0]['text'] as String;
        final parsed = _parseDailyPlanResponseWithDuration(text);
        final dailyPlan = parsed['plan'] as List<Map<String, dynamic>>;
        final duration = parsed['duration'] as int? ?? dailyPlan.length;
        for (int i = 0; i < dailyPlan.length; i++) {
          dailyPlan[i]['duration'] = duration;
        }
        return dailyPlan;
      }
    } catch (e) {
      debugPrint('Error generating continuation plan: $e');
    }
    return [];
  }

  // Cohere Implementation (Free Tier)
  Future<List<String>> _generateWithCohere({
    required String crop,
    required String goal,
    required List<Map<String, dynamic>> weatherData,
    required String location,
  }) async {
    try {
      final weatherSummary = weatherData
          .asMap()
          .entries
          .map((entry) {
            final i = entry.key;
            final day = entry.value;
            final temp = day['temp_max'] ?? day['temperature'] ?? 'N/A';
            final rain = day['precipitation_sum'] ?? day['rain'] ?? 'N/A';
            final desc = day['desc'] ?? day['description'] ?? 'N/A';
            return 'Day ${i + 1}: $desc, Temp: $temp°C, Rain: $rain mm';
          })
          .join('\n');
      final prompt = '''
Generate farming recommendations for $crop cultivation in $location.
Goal: $goal
14-day Weather Forecast:
$weatherSummary

Provide 5-7 specific, actionable recommendations. Format your response as clearly separated paragraphs or as a numbered or bulleted outline—whichever is most suitable for the recommendations. Each recommendation should be distinct and easy to read.
''';

      final response = await http.post(
        Uri.parse('https://api.cohere.ai/v1/generate'),
        headers: {
          'Authorization': 'Bearer $cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'command',
          'prompt': prompt,
          'max_tokens': 800,
          'temperature': 0.7,
          'k': 0,
          'stop_sequences': [],
          'return_likelihoods': 'NONE',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['generations'][0]['text'] as String;
        return _parseAIResponse(text);
      }
    } catch (e) {
      // print('Cohere API error: $e');
    }
    return [];
  }

  /// Ask a question with chat history using Cohere's chat endpoint for context-aware responses
  Future<String?> askQuestionWithHistory(
    List<Map<String, String>> history, {
    required String userName,
    required String userProfession,
    required String userLocation,
    required List<String> primaryCrops,
  }) async {
    try {
      // Always prepend a system context message with user profile details
      final contextMessage = {
        "role": "system",
        "message":
            "You are an expert in farming, agriculture, and weather. Only answer queries related to the topics of this app or about the user's profile details (full name, primary crops, farm location, profession). Never answer questions outside these topics. Always know and use the user's profile details in your responses, and never answer questions unrelated to these topics.\n\nUser Profile:\n- Name: $userName\n- Profession: $userProfession\n- Farm Location: $userLocation\n- Primary Crops: ${primaryCrops.isNotEmpty ? primaryCrops.join(", ") : 'None specified'}\n",
      };
      final fullHistory = [contextMessage, ...history];
      final url = Uri.parse('https://api.cohere.ai/v1/chat');
      final headers = {
        'Authorization': 'Bearer $cohereApiKey',
        'Content-Type': 'application/json',
      };
      final body = json.encode({
        'chat_history': fullHistory.sublist(
          0,
          fullHistory.length - 1,
        ), // all but last
        'message': fullHistory.last['message'], // latest user message
        'model': 'command',
        'temperature': 0.7,
      });
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text']?.toString().trim();
      } else {
        return "Sorry, the AI service is currently unavailable. (${response.statusCode})";
      }
    } catch (e) {
      return "Error contacting AI service: $e";
    }
  }

  // Response Parsing Methods
  List<String> _parseAIResponse(String response) {
    // Try splitting by two or more newlines first
    List<String> paragraphs =
        response
            .split(RegExp(r'(\r?\n){2,}'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();

    // If only one paragraph, try splitting by numbered list (e.g., 1. 2. 3.)
    if (paragraphs.length <= 1) {
      paragraphs =
          response
              .split(RegExp(r'(?<=\d\.)\s+'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();
    }

    // If still only one, try splitting by single newlines
    if (paragraphs.length <= 1) {
      paragraphs =
          response
              .split(RegExp(r'\r?\n'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();
    }

    // Filter out introductory/irrelevant text and keep actionable recommendations
    final recommendations =
        paragraphs
            .where(
              (p) =>
                  !p.toLowerCase().contains('you are an expert') &&
                  !p.toLowerCase().contains('based on the current weather') &&
                  !p.toLowerCase().contains('current weather:') &&
                  !p.toLowerCase().contains('provide recommendations') &&
                  !p.toLowerCase().contains('format each recommendation') &&
                  !p.toLowerCase().contains('keep each recommendation') &&
                  !p.toLowerCase().contains('focus on the most important') &&
                  p.length > 10 &&
                  p.length < 500,
            )
            .toList();

    // Return up to 6 recommendations for more detail
    return recommendations.length > 6
        ? recommendations.sublist(0, 6)
        : recommendations;
  }

  // Helper to extract total duration from AI response
  int? _extractDuration(String response) {
    final match = RegExp(
      r'(total|typical|estimated)[^\d]*(\d+)\s*days',
      caseSensitive: false,
    ).firstMatch(response);
    if (match != null) {
      return int.tryParse(match.group(2)!);
    }
    // Also handle lines like 'Here is a 140-day plan' or 'This is a 120-day plan'
    final altMatch = RegExp(
      r'(\d+)\s*-?day plan',
      caseSensitive: false,
    ).firstMatch(response);
    if (altMatch != null) {
      return int.tryParse(altMatch.group(1)!);
    }
    return null;
  }

  // Updated: Parse daily plan and extract duration
  Map<String, dynamic> _parseDailyPlanResponseWithDuration(String response) {
    final lines = response.split('\n');
    final dailyPlan = <Map<String, dynamic>>[];
    String currentTitle = '';
    List<String> currentTasks = [];
    String currentNotes = '';
    int? duration;
    int startIndex = 0;

    // Try to extract duration from the first few lines
    for (int i = 0; i < lines.length && i < 3; i++) {
      final line = lines[i].trim();
      final d = _extractDuration(line);
      if (d != null) {
        duration = d;
        startIndex = i + 1; // skip this line in plan parsing
        break;
      }
    }

    // Skip lines until the first 'Day X:'
    bool foundFirstDay = false;
    for (int i = startIndex; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;

      if (!foundFirstDay) {
        if (RegExp(r'^Day\s*\d+:', caseSensitive: false).hasMatch(trimmed)) {
          foundFirstDay = true;
        } else {
          continue;
        }
      }

      if (trimmed.toLowerCase().contains('day') && trimmed.contains(':')) {
        // Save previous day if exists
        if (currentTitle.isNotEmpty) {
          dailyPlan.add({
            'title': currentTitle,
            'tasks': currentTasks,
            'notes': currentNotes,
          });
        }
        // Start new day
        currentTitle = trimmed;
        currentTasks = [];
        currentNotes = '';
      } else if (trimmed.startsWith('-') ||
          trimmed.startsWith('•') ||
          trimmed.startsWith('*')) {
        currentTasks.add(
          trimmed.replaceAll(RegExp(r'^[\-\•\*\s]+'), '').trim(),
        );
      } else if (trimmed.toLowerCase().startsWith('notes:')) {
        currentNotes = trimmed.substring(6).trim();
      } else if (currentTitle.isNotEmpty && trimmed.isNotEmpty) {
        currentNotes += '$trimmed ';
      }
    }
    // Add the last day
    if (currentTitle.isNotEmpty) {
      dailyPlan.add({
        'title': currentTitle,
        'tasks': currentTasks,
        'notes': currentNotes.trim(),
      });
    }
    return {'duration': duration, 'plan': dailyPlan};
  }

  // Additional AI methods for daily plan and weather advice
  Future<List<Map<String, dynamic>>> _generateDailyPlanWithCohere({
    required String crop,
    required String goal,
    required List<Map<String, dynamic>> weatherData,
    required String location,
  }) async {
    try {
      final weatherSummary = weatherData
          .asMap()
          .entries
          .map((entry) {
            final i = entry.key;
            final day = entry.value;
            final temp = day['temp_max'] ?? day['temperature'] ?? 'N/A';
            final rain = day['precipitation_sum'] ?? day['rain'] ?? 'N/A';
            final desc = day['desc'] ?? day['description'] ?? 'N/A';
            return 'Day ${i + 1}: $desc, Temp: $temp°C, Rain: $rain mm';
          })
          .join('\n');
      final prompt = '''
Estimate the total number of days required for the full growing cycle of $crop in $location, based on typical agronomic knowledge.

Now, generate a detailed plan for the first 14 days only, starting from Day 1. Focus on the appropriate early-stage activities for this crop and do not include harvest or post-harvest activities unless they naturally occur within the first 14 days.

14-day Weather Forecast:
$weatherSummary

For each day, specify the day number and the recommended activity. If there are days when no farming activity is needed, explicitly state "No tasks today" or suggest monitoring, resting, or waiting. Do not skip any days in the sequence.

Format:
Day 1: [Title]
- Task 1
- Task 2
Notes: [Additional notes or considerations]

Continue for each day up to Day 14. Do not skip any days; if a day has no tasks, state so explicitly.
''';

      final response = await http.post(
        Uri.parse('https://api.cohere.ai/v1/generate'),
        headers: {
          'Authorization': 'Bearer $cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'command',
          'prompt': prompt,
          'max_tokens': 1200,
          'temperature': 0.7,
          'k': 0,
          'stop_sequences': [],
          'return_likelihoods': 'NONE',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['generations'][0]['text'] as String;
        final parsed = _parseDailyPlanResponseWithDuration(text);
        final dailyPlan = parsed['plan'] as List<Map<String, dynamic>>;
        final duration = parsed['duration'] as int? ?? dailyPlan.length;
        // Set the correct duration for each day
        for (int i = 0; i < dailyPlan.length; i++) {
          dailyPlan[i]['duration'] = duration;
        }
        return dailyPlan;
      }
    } catch (e) {
      // print('Error generating daily plan with AI: $e');
    }
    return [];
  }

  Future<List<String>> _generateWeatherAdviceWithCohere({
    required String crop,
    required Map<String, dynamic> weatherData,
    required String location,
  }) async {
    try {
      final temp = weatherData['temperature']?.toString() ?? '25';
      final humidity = weatherData['humidity']?.toString() ?? '65';
      final windSpeed = weatherData['wind_speed']?.toString() ?? '8';
      final pressure = weatherData['pressure']?.toString() ?? '1013';
      final rain = weatherData['rain']?.toString() ?? '0';
      final clouds = weatherData['clouds']?.toString() ?? '0';
      final windDirection = weatherData['wind_direction']?.toString() ?? '';
      DateTime.now().hour.toString().padLeft(2, '0');

      final prompt = '''
Please provide smart farming recommendations for $crop in $location based on the following weather data:
- Temperature: $temp°C, Humidity: $humidity%, Wind Speed: $windSpeed m/s, Pressure: $pressure hPa, Rain: $rain mm, Clouds: $clouds%, Wind Direction: $windDirection

Format your response as follows:
1. Start with a short, clear headline.
2. Then, list 2-4 actionable recommendations as bullet points (using '-').
3. End with a tip, starting with 'Tip:'.
- Do not only give a summary or headline.
- Do not cut off your response.
- Do not include any other text or explanations.
''';

      final response = await http.post(
        Uri.parse('https://api.cohere.ai/v1/generate'),
        headers: {
          'Authorization': 'Bearer $cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'command',
          'prompt': prompt,
          'max_tokens': 600,
          'temperature': 0.7,
          'k': 0,
          'stop_sequences': [],
          'return_likelihoods': 'NONE',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['generations'][0]['text'] as String;
        final recs = _parseStructuredAIResponse(text);
        if (recs.isEmpty) {
          return [
            "Monitor your $crop closely and adjust irrigation based on current weather conditions.",
          ];
        }
        return recs;
      }
    } catch (e) {
      // print('Error generating weather advice with AI: $e');
    }
    // Fallback in case of error or no return above
    return [
      "Monitor your $crop closely and adjust irrigation based on current weather conditions.",
    ];
  }

  /// Improved parser for structured AI recommendations (headline, bullets, tip)
  List<String> _parseStructuredAIResponse(String response) {
    // Split by double newlines to get separate recommendations
    final blocks =
        response
            .split(RegExp(r'\n{2,}'))
            .map((b) => b.trim())
            .where((b) => b.isNotEmpty)
            .toList();
    List<String> recommendations = [];
    for (final block in blocks) {
      // If block contains at least a headline and a bullet, keep it
      final lines =
          block
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
      if (lines.isEmpty) continue;
      // If the first line is a headline (not a bullet), keep as headline
      String headline = lines[0];
      List<String> bullets = [];
      String? tip;
      for (int i = 1; i < lines.length; i++) {
        final l = lines[i];
        if (l.startsWith('-')) {
          bullets.add(l);
        } else if (l.toLowerCase().startsWith('tip:')) {
          tip = l;
        }
      }
      // Reconstruct the block in the expected format
      String rec = headline;
      if (bullets.isNotEmpty) rec += '\n${bullets.join('\n')}';
      if (tip != null) rec += '\n$tip';
      recommendations.add(rec);
    }
    // If nothing parsed, fallback to splitting by single newlines
    if (recommendations.isEmpty) {
      return response
          .split(RegExp(r'\n{1,2}'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }
    // Limit to 3 recommendations for clarity
    return recommendations.length > 3
        ? recommendations.sublist(0, 3)
        : recommendations;
  }
}
