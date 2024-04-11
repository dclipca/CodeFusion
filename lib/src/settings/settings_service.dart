import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service that stores and retrieves user settings.
///
/// By default, this class does not persist user settings. If you'd like to
/// persist the user settings locally, use the shared_preferences package. If
/// you'd like to store settings on a web server, use the http package.
class SettingsService {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  // Key names for storing data
  static const String _themeModeKey = 'themeMode';
  static const String _pathOptionKey = 'pathOption';

  /// Loads the User's preferred ThemeMode from local storage.
  Future<ThemeMode> themeMode() async {
    final SharedPreferences prefs = await _prefs;
    final String? mode = prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (e) => e.toString() == mode,
      orElse: () => ThemeMode.system, // Default value
    );
  }

  /// Persists the user's preferred ThemeMode to local storage.
  Future<void> updateThemeMode(ThemeMode theme) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_themeModeKey, theme.toString());
  }

  /// Loads the User's path option from local storage.
  Future<PathOption> pathOption() async {
    final SharedPreferences prefs = await _prefs;
    final String? option = prefs.getString(_pathOptionKey);
    return PathOption.values.firstWhere(
      (e) => e.toString() == option,
      orElse: () => PathOption.full, // Default value
    );
  }

  /// Persists the user's path option to local storage.
  Future<void> updatePathOption(PathOption option) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_pathOptionKey, option.toString());
  }
}
