import 'package:flutter/material.dart';
import 'models.dart';

/// رەنگێن ئەپی — 🌙 تاری / ☀️ رۆهن
/// [dark] ژ لایێ ThemeController ڤە دهێتە گوهۆڕین.
class AppColors {
  /// ڕووکار: dark · light · red (ل سەر سۆری) · pink (ل سەر سپی)
  static String mode = 'dark';
  static bool get dark => mode == 'dark' || mode == 'red';
  static set dark(bool d) => mode = d ? 'dark' : 'light';
  static bool get isRed => mode == 'red';
  static bool get isPink => mode == 'pink';

  static T _m<T>(T d, T l, T r, T p) => switch (mode) { 'light' => l, 'red' => r, 'pink' => p, _ => d };

  static Color get _ink => isPink ? const Color(0xFF3A1F2B) : const Color(0xFF1E2B32); // نڤیسین ل سەر رۆهنی

  static Color get bg => _m(const Color(0xFF131F24), const Color(0xFFF4F7F8), const Color(0xFF1C080C), const Color(0xFFFFF6F9));
  static Color get card => _m(const Color(0xFF202F36), Colors.white, const Color(0xFF2E1016), Colors.white);
  static Color get cardAlt => _m(const Color(0xFF1A282E), const Color(0xFFF0F4F6), const Color(0xFF260C11), const Color(0xFFFFEDF3));
  static Color get chip => _m(const Color(0xFF253740), const Color(0xFFE7EDF0), const Color(0xFF42161F), const Color(0xFFFFDFEA));
  static Color get tint => _m(const Color(0xFF1B3A4B), const Color(0xFFE2F3FC), const Color(0xFF4A1420), const Color(0xFFFFE4EE));
  static Color get germanText => _m(const Color(0xFFBEE9FF), const Color(0xFF0B6E99), const Color(0xFFFFD3D8), const Color(0xFFB81862));

  /// 🎨 رەنگێ سەرەکی یێ ڕووکاری (دوگمەیێن دەنگی، هەلبژارتن، لینک …)
  static Color get accent => _m(blue, blue, const Color(0xFFFF7088), const Color(0xFFEC4899));

  /// شێوەیێن گرتی ل رێکێ (ڕوو / لێڤ) و هێلا دناڤبەرا وان
  static Color get lockFace => _m(const Color(0xFF37464F), const Color(0xFFE5E8EA), const Color(0xFF4A2129), const Color(0xFFF6DDE6));
  static Color get lockLip => _m(const Color(0xFF26333A), const Color(0xFFC9CED1), const Color(0xFF34141A), const Color(0xFFE6BFCD));
  static Color get lockIcon => _m(const Color(0xFF52656D), const Color(0xFFAFB6BA), const Color(0xFF7A4650), const Color(0xFFD59BB1));

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
  final String? subtitle; // 💬 رامان ل بن هەلبژارتنێ (هاریکاری)
  const OptionTile({super.key, required this.text, required this.selected, this.stateColor, this.onTap, this.textDirection, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = stateColor ?? (selected ? AppColors.accent : AppColors.fg24);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: subtitle == null ? 18 : 12),
        decoration: BoxDecoration(
          color: selected || stateColor != null ? c.withValues(alpha: 0.18) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            text,
            textAlign: TextAlign.center,
            textDirection: textDirection,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: selected || stateColor != null ? c : AppColors.fg),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 14.5, color: AppColors.fg60, fontWeight: FontWeight.w600, height: 1.4)),
          ],
        ]),
      ),
    );
  }
}
