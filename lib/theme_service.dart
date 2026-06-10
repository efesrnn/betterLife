import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  final notifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? true;
    notifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final goingDark = notifier.value == ThemeMode.light;
    notifier.value = goingDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', goingDark);
  }

  bool get isDark => notifier.value == ThemeMode.dark;
}