import 'package:flutter/material.dart';
import 'models.dart';

/// رەنگێن ئەپی — 🌙 تاری / ☀️ رۆهن
/// [dark] ژ لایێ ThemeController ڤە دهێتە گوهۆڕین.
class AppColors {
  static bool dark = true;
  static const _ink = Color(0xFF1E2B32); // نڤیسین ل سەر رۆهنی

  static Color get bg => dark ? const Color(0xFF131F24) : const Color(0xFFF4F7F8);
  static Color get card => dark ? const Color(0xFF202F36) : Colors.white;
  static Color get cardAlt => dark ? const Color(0xFF1A282E) : const Color(0xFFF0F4F6);
  static Color get chip => dark ? const Color(0xFF253740) : const Color(0xFFE7EDF0);
  static Color get tint => dark ? const Color(0xFF1B3A4B) : const Color(0xFFE2F3FC);
  static Color get germanText => dark ? const Color(0xFFBEE9FF) : const Color(0xFF0B6E99);

  /// رەنگێ نڤیسینێ (سپی ل تاری، رەش ل رۆهنی) و ئاستێن وێ
  static Color get fg => dark ? Colors.white : _ink;
  static Color _a(Color d, double a) => dark ? d : _ink.withValues(alpha: a);
  static Color get fg70 => _a(Colors.white70, 0.72);
  static Color get fg60 => _a(Colors.white60, 0.62);
  static Color get fg54 => _a(Colors.white54, 0.56);
  static Color get fg38 => _a(Colors.white38, 0.42);
  static Color get fg30 => _a(Colors.white30, 0.30);
  static Color get fg24 => _a(Colors.white24, 0.20);
  static Color get fg12 => _a(Colors.white12, 0.10);
  static Color get fg10 => _a(Colors.white10, 0.08);

  /// زێڕی بۆ نڤیسینێ (ل رۆهنی تاریتر دا بهێتە خواندن)
  static Color get goldText => dark ? gold : const Color(0xFFB86E00);

  static const green = Color(0xFF58CC02);
  static const blue = Color(0xFF1CB0F6);
  static const red = Color(0xFFFF4B4B);
  static const gold = Color(0xFFFFC800);
  static const orange = Color(0xFFFF9600);
}

/// وەرگێڕانا دەقێن ڕووکارێ ئەپی ب هەرسێ زمانان
String tr(AppLanguage l, String ku, String de, String en) => switch (l) {
      AppLanguage.badini => ku,
      AppLanguage.german => de,
      AppLanguage.english => en,
    };

/// دوگمەیا مەزن ب شێوازێ Duolingo
class BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  const BigButton({super.key, required this.label, required this.onPressed, this.color = AppColors.green, this.icon});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.card,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

/// کارتا هەلبژارتنێ
class OptionTile extends StatelessWidget {
  final String text;
  final bool selected;
  final Color? stateColor; // سەوز/سۆر پشتی پشکنینێ
  final VoidCallback? onTap;
  final TextDirection? textDirection;
  const OptionTile({super.key, required this.text, required this.selected, this.stateColor, this.onTap, this.textDirection});

  @override
  Widget build(BuildContext context) {
    final c = stateColor ?? (selected ? AppColors.blue : Colors.white24);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected || stateColor != null ? c.withValues(alpha: 0.18) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c, width: 2),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          textDirection: textDirection,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: selected || stateColor != null ? c : AppColors.fg),
        ),
      ),
    );
  }
}
