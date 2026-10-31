import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/backend.dart';

/// 🧑‍🏫 کاریکاتێرێن ASP — مامۆستا پرسیاران دکەت و ب ڕیئاکشن بەرسڤێ ددەت.
enum MascotMood { ask, listen, speak, happy, sad }

/// کاریکاتێرەکێ ئامادە: front / side
class MascotChar {
  final String front, side;
  const MascotChar(this.front, this.side);

  static const teacher = MascotChar('assets/mascot/teacher_front.webp', 'assets/mascot/teacher_side.webp');
  static const boy = MascotChar('assets/mascot/boy_front.webp', 'assets/mascot/boy_side.webp');
  static const kid = MascotChar('assets/mascot/kid_front.webp', 'assets/mascot/kid_side.webp');
  static const happyPhoto = 'assets/mascot/teacher_happy.webp';

  /// کاریکاتێرێ سەرەکی بۆ ڤی بکارهێنەری (دێ بۆ ئافرەتان کاریکاتێرەکا ئافرەت هێت دەمێ وێنە هاتە زێدەکرن)
  static MascotChar forUser() {
    final g = Backend.instance.gender;
    return g == 'f' ? teacher : teacher;
  }

  /// بۆ دیالۆگان: هەر ئاخفتنکەرەکی کاریکاتێرەک
  static const cast = [teacher, boy, kid];
}

const _praise = [
  'دەستخۆش! 👏',
  'زۆر باشە! 🌟',
  'تو قارەمانی! 💪',
  'نایاب! 🎉',
  'هەر وەسا بەردەوام بە! 🚀',
  'ئافەرین! ✨',
];
const _comfort = [
  'نە خەم، جارا بێت! 💪',
  'نێزیک بوو! 🙂',
  'هێدی هێدی فێر دبین 🌱',
  'دیسا تاقی بکە، تو دشێی!',
];

String randomPraise() => _praise[Random().nextInt(_praise.length)];
String randomComfort() => _comfort[Random().nextInt(_comfort.length)];

/// مامۆستا + بالۆنا ئاخفتنێ. دەمێ [mood] دگوهۆڕیت، ڕیئاکشن دکەت (بازدان / هەژاندن).
class MascotSays extends StatefulWidget {
  final MascotMood mood;
  final String text;
  final double height;
  final MascotChar char;
  final TextDirection textDirection;
  MascotSays({
    super.key,
    required this.mood,
    required this.text,
    this.height = 112,
    MascotChar? char,
    this.textDirection = TextDirection.rtl,
  }) : char = char ?? MascotChar.forUser();

  @override
  State<MascotSays> createState() => _MascotSaysState();
}

class _MascotSaysState extends State<MascotSays> with TickerProviderStateMixin {
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  late final AnimationController _react = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(MascotSays old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood && (widget.mood == MascotMood.happy || widget.mood == MascotMood.sad)) {
      _react.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _react.dispose();
    super.dispose();
  }

  String get _badge => switch (widget.mood) {
        MascotMood.ask => '❓',
        MascotMood.listen => '🎧',
        MascotMood.speak => '🎤',
        MascotMood.happy => '🎉',
        MascotMood.sad => '😕',
      };

  Color get _bubbleColor => switch (widget.mood) {
        MascotMood.happy => const Color(0xFF1F4D1A),
        MascotMood.sad => const Color(0xFF4D1F1F),
        _ => const Color(0xFF202F36),
      };

  @override
  Widget build(BuildContext context) {
    final img = widget.mood == MascotMood.listen ? widget.char.side : widget.char.front;
    final figure = AnimatedBuilder(
      animation: Listenable.merge([_idle, _react]),
      builder: (_, child) {
        final t = _react.value;
        double dy = -2.5 * _idle.value, dx = 0, rot = 0, scale = 1;
        if (_react.isAnimating || t > 0 && t < 1) {
          if (widget.mood == MascotMood.happy) {
            dy -= 26 * sin(pi * t) * (1 - t * 0.3); // بازدان
            scale = 1 + 0.08 * sin(pi * t);
          } else if (widget.mood == MascotMood.sad) {
            dx = 9 * sin(t * pi * 6) * (1 - t); // سەرێ خۆ دهەژینیت
            rot = -0.05 * sin(t * pi * 3) * (1 - t);
          }
        }
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(angle: rot, child: Transform.scale(scale: scale, child: child)),
        );
      },
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Image.asset(img, key: ValueKey(img), height: widget.height, filterQuality: FilterQuality.medium),
        ),
        Positioned(
          top: -4,
          right: -6,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(_badge, key: ValueKey(_badge), style: const TextStyle(fontSize: 22)),
          ),
        ),
      ]),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        figure,
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: EdgeInsets.only(bottom: widget.height * 0.35),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _bubbleColor,
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomLeft: widget.textDirection == TextDirection.ltr ? const Radius.circular(4) : null,
                bottomRight: widget.textDirection == TextDirection.rtl ? const Radius.circular(4) : null,
              ),
              border: Border.all(color: Colors.white24),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                widget.text,
                key: ValueKey(widget.text),
                textDirection: widget.textDirection,
                style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// وێنەیێ بازنەیی (سەر و ملان) بۆ دیالۆگان
class MascotAvatar extends StatelessWidget {
  final MascotChar char;
  final double size;
  final Color ring;
  const MascotAvatar({super.key, required this.char, this.size = 46, this.ring = Colors.white24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2B3B44), border: Border.all(color: ring, width: 2)),
      child: ClipOval(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxWidth: size * 1.9,
          maxHeight: double.infinity,
          child: Padding(
            padding: EdgeInsets.only(top: size * 0.06),
            child: Image.asset(char.front, width: size * 1.9, fit: BoxFit.fitWidth, alignment: Alignment.topCenter),
          ),
        ),
      ),
    );
  }
}
