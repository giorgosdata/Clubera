import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class WeatherData {
  final int tempC;
  final String description;
  final int conditionId;
  final int windKmh;

  const WeatherData({
    required this.tempC,
    required this.description,
    required this.conditionId,
    required this.windKmh,
  });

  String get emoji {
    if (conditionId >= 200 && conditionId < 300) return '⛈';
    if (conditionId >= 300 && conditionId < 400) return '🌦';
    if (conditionId >= 500 && conditionId < 600) return '🌧';
    if (conditionId >= 600 && conditionId < 700) return '❄️';
    if (conditionId >= 700 && conditionId < 800) return '🌫';
    if (conditionId == 800) return '☀️';
    return '⛅';
  }
}

class WeatherService {
  static const _base = 'https://api.openweathermap.org/data/2.5';

  static Future<WeatherData?> forMatch(String city, DateTime matchTime) async {
    final key = AppConfig.openWeatherApiKey;
    if (key.isEmpty) return null;

    try {
      final now = DateTime.now();
      final diff = matchTime.difference(now);

      if (diff.inHours <= 3) {
        // Current weather
        final url = '$_base/weather?q=${Uri.encodeComponent(city)}&appid=$key&units=metric&lang=el';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (res.statusCode != 200) return null;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return WeatherData(
          tempC: (data['main']['temp'] as num).round(),
          description: (data['weather'] as List).first['description'] ?? '',
          conditionId: (data['weather'] as List).first['id'] ?? 800,
          windKmh: ((data['wind']['speed'] as num) * 3.6).round(),
        );
      } else if (diff.inDays <= 4) {
        // 5-day forecast
        final url = '$_base/forecast?q=${Uri.encodeComponent(city)}&appid=$key&units=metric&lang=el';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (res.statusCode != 200) return null;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['list'] as List).cast<Map<String, dynamic>>();
        final matchTs = matchTime.millisecondsSinceEpoch / 1000;
        final entry = list.reduce((a, b) {
          final aDiff = ((a['dt'] as num) - matchTs).abs();
          final bDiff = ((b['dt'] as num) - matchTs).abs();
          return aDiff < bDiff ? a : b;
        });
        return WeatherData(
          tempC: (entry['main']['temp'] as num).round(),
          description: (entry['weather'] as List).first['description'] ?? '',
          conditionId: (entry['weather'] as List).first['id'] ?? 800,
          windKmh: ((entry['wind']['speed'] as num) * 3.6).round(),
        );
      }
      return null; // Too far in the future
    } catch (_) {
      return null;
    }
  }
}
