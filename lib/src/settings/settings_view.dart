import 'package:flutter/material.dart';
import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.controller});

  static const routeName = '/settings';

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Theme Mode'),
            DropdownButtonHideUnderline(
              child: DropdownButton<ThemeMode>(
                // This removes the dropdown button's underline
                // Read the selected themeMode from the controller
                value: controller.themeMode,
                // Call the updateThemeMode method any time the user selects a theme.
                onChanged: controller.updateThemeMode,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System Theme'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light Theme'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark Theme'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20), // Space between dropdowns
            const Text('Path Display Option'),
            DropdownButtonHideUnderline(
              child: DropdownButton<PathOption>(
                // This removes the dropdown button's underline
                value: controller.pathOption,
                onChanged: (newValue) {
                  if (newValue != null) {
                    controller.updatePathOption(newValue);
                  }
                },
                items: PathOption.values.map((option) {
                  return DropdownMenuItem<PathOption>(
                    value: option,
                    child: Text(option == PathOption.full ? 'Full Path' : 'Relative Path'),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}