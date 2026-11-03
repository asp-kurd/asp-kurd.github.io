import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui.dart';

/// 🌗 ڕووکار: تاری / رۆهن / وەکی مۆبایلێ
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._();
  static final instance = ThemeController._();

  static const modes = ['dark', 'light', 'system'];
  String mode = 'dark';
  bool _started = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    mode = p.getString('theme_mode') ?? 'dark';
    AppColors.dark = _computeDark();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _computeDark() => switch (mode) {
        'light' => false,
        'system' => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
        _ => true,
      };

  void markStarted() => _started = true;

  void _apply() {
    final d = _computeDark();
    if (d == AppColors.dark) return;
    AppColors.dark = d;
    notifyListeners();
    // هەمی شاشە ژ نوو دهێنە ئاڤاکرن (بێ کو ئەو شاشا تو تێدای بهێتە گرتن)
    if (_started) WidgetsBinding.instance.reassembleApplication();
  }

  Future<void> setMode(String m) async {
    mode = m;
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_mode', m);
    _apply();
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    if (mode == 'system') _apply();
  }
}
