import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language. Greek is the default; the choice is remembered on the device.
class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';
  static const supported = ['el', 'en', 'es', 'pt', 'it', 'fr', 'tr', 'de'];

  Locale _locale = const Locale('el');
  Locale get locale => _locale;

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && supported.contains(saved)) {
        _locale = Locale(saved);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String code) async {
    if (!supported.contains(code)) return;
    _locale = Locale(code);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, code);
    } catch (_) {}
  }
}
