import 'package:flutter/material.dart';
import 'models.dart';

/// رەنگێن ئەپی
class AppColors {
  static const bg = Color(0xFF131F24);
  static const card = Color(0xFF202F36);
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: selected || stateColor != null ? c : Colors.white),
        ),
      ),
    );
  }
}
