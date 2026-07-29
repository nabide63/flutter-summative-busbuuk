// Persists lightweight user preferences (SharedPreferences) so they survive
// an app restart: notifications toggle, language choice, and text size.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TextSizeOption { small, medium, large }

extension TextSizeOptionX on TextSizeOption {
  String get label => switch (this) {
        TextSizeOption.small => 'Small',
        TextSizeOption.medium => 'Medium',
        TextSizeOption.large => 'Large',
      };

  double get scale => switch (this) {
        TextSizeOption.small => 0.9,
        TextSizeOption.medium => 1.0,
        TextSizeOption.large => 1.15,
      };
}

const _kNotificationsEnabled = 'notificationsEnabled';
const _kLanguage = 'language';
const _kTextSize = 'textSize';

class SettingsProvider extends ChangeNotifier {
  bool _notificationsEnabled = true;
  String _language = 'English';
  TextSizeOption _textSize = TextSizeOption.medium;
  bool _isLoaded = false;

  bool get notificationsEnabled => _notificationsEnabled;
  String get language => _language;
  TextSizeOption get textSize => _textSize;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_kNotificationsEnabled) ?? true;
    _language = prefs.getString(_kLanguage) ?? 'English';
    _textSize = TextSizeOption.values.firstWhere(
      (option) => option.name == prefs.getString(_kTextSize),
      orElse: () => TextSizeOption.medium,
    );
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabled, value);
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, value);
  }

  Future<void> setTextSize(TextSizeOption value) async {
    _textSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTextSize, value.name);
  }
}
