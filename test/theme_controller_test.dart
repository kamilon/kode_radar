import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('parseMode maps stored strings to ThemeMode (default system)', () {
    expect(ThemeController.parseMode('light'), ThemeMode.light);
    expect(ThemeController.parseMode('dark'), ThemeMode.dark);
    expect(ThemeController.parseMode('system'), ThemeMode.system);
    expect(ThemeController.parseMode(null), ThemeMode.system);
    expect(ThemeController.parseMode('bogus'), ThemeMode.system);
  });

  test('setMode persists the choice and load restores it', () async {
    final controller = ThemeController.instance;

    await controller.setMode(ThemeMode.dark);
    expect(controller.mode, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeController.storageKey), 'dark');

    // Persist a value and confirm load() reads it back.
    await prefs.setString(ThemeController.storageKey, 'light');
    await controller.load();
    expect(controller.mode, ThemeMode.light);
  });
}
