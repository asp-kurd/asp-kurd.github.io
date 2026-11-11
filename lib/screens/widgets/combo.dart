import 'dart:math';

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/rewards_service.dart';
import '../../ui.dart';
import 'mascot.dart';

/// ⚡ کۆمبۆ: بەرسڤێن دروست ل دویڤ ئێک
/// < ١٠ ئاسایی · ١٠–١٤ کەسکێ گەش ب بازنەیەکا زیندی · ١٥+ برووسکا شین 🌩️
int comboTier(int combo) => combo >= 15 ? 2 : (combo >= 10 ? 1 : 0);

String kuNum(int n) => n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

// ───────────────────────── خەتا پێشکەفتنێ ─────────────────────────
class ComboBar extends StatefulWidget {
  final double value;
  final int combo;
  final Color color;
  final double height;
  const ComboBar({super.key, required this.value, required this.combo, this.color = AppColors.green, this.height = 12});

  @override
  State<ComboBar> createState() => _ComboBarState();
}

class _ComboBarState extends State<ComboBar> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ComboBar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (comboTier(widget.combo) > 0) {
      if (!_t.isAnimating) _t.repeat();
    } else {
      _t.stop();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = comboTier(widget.combo);
    final h = widget.height;
    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) {
        final v = _t.value;
        final pulse = 0.5 + 0.5 * sin(v * 2 * pi);
        final glow = switch (tier) {
          1 => [BoxShadow(color: const Color(0xFF58CC02).withValues(alpha: 0.35 + 0.35 * pulse), blurRadius: 10 + 8 * pulse, spreadRadius: 1)],
          2 => [BoxShadow(color: const Color(0xFF3FD0FF).withValues(alpha: 0.45 + 0.4 * pulse), blurRadius: 14 + 10 * pulse, spreadRadius: 2)],
          _ => const <BoxShadow>[],
        };
        final fill = switch (tier) {
          1 => LinearGradient(
              colors: const [Color(0xFF3FAE00), Color(0xFFB7FF4A), Color(0xFF58CC02)],
              stops: [0, (v * 1.4 - 0.2).clamp(0.0, 1.0), 1],
            ),
          2 => LinearGradient(
              colors: const [Color(0xFF1C6CF6), Color(0xFF3FD0FF), Colors.white, Color(0xFF3FD0FF)],
              stops: [0, (v - 0.15).clamp(0.0, 1.0), v, (v + 0.15).clamp(0.0, 1.0)],
            ),
          _ => LinearGradient(colors: [widget.color, Color.lerp(widget.color, Colors.white, 0.18)!]),
        };
        return SizedBox(
          height: h + 14,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            // خەت
            Container(
              height: h,
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(h), boxShadow: glow),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  widthFactor: widget.value.clamp(0.02, 1.0),
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(gradient: fill, borderRadius: BorderRadius.circular(h)),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(h * 0.6, h * 0.18, h * 0.6, 0),
                        height: h * 0.25,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(h)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ١٠+: بازنەیەکا رەنگین ل دۆر خەتێ دزڤڕیت
            if (tier == 1)
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _OrbitBorder(v, h))),
              ),
            // ١٥+: برووسک (ل سەر بەشێ پڕکری)
            if (tier == 2)
              Positioned.fill(
                child: IgnorePointer(
                  child: Directionality.of(context) == TextDirection.rtl
                      ? Transform.flip(flipX: true, child: CustomPaint(painter: _Lightning(v, h, widget.value)))
                      : CustomPaint(painter: _Lightning(v, h, widget.value)),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _OrbitBorder extends CustomPainter {
  final double v, h;
  _OrbitBorder(this.v, this.h);
  @override
  void paint(Canvas canvas, Size s) {
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: s.center(Offset.zero), width: s.width + 6, height: h + 6), Radius.circular(h));
    final rect = r.outerRect;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        transform: GradientRotation(v * 2 * pi),
        colors: const [Colors.transparent, Color(0xFFB7FF4A), Colors.white, Color(0xFF58CC02), Colors.transparent, Colors.transparent],
        stops: const [0, 0.12, 0.18, 0.26, 0.4, 1],
      ).createShader(rect);
    canvas.drawRRect(r, p);
  }

  @override
  bool shouldRepaint(_OrbitBorder o) => o.v != v;
}

class _Lightning extends CustomPainter {
  final double v, h, fill;
  _Lightning(this.v, this.h, this.fill);
  @override
  void paint(Canvas canvas, Size s) {
    // هەر ~٩٠ms برووسکەکا نوو
    final rng = Random((v * 16).floor() * 7919);
    final cy = s.height / 2;
    final w = s.width * fill.clamp(0.15, 1.0);
    final bolts = 1 + rng.nextInt(2);
    for (var b = 0; b < bolts; b++) {
      final path = Path();
      var x = rng.nextDouble() * w * 0.4;
      final end = x + w * (0.3 + rng.nextDouble() * 0.5);
      var y = cy + (rng.nextBool() ? -1 : 1) * (h * 0.2 + rng.nextDouble() * h * 0.6);
      path.moveTo(x, y);
      while (x < end && x < w) {
        x += 8 + rng.nextDouble() * 16;
        y = cy + (rng.nextDouble() * 2 - 1) * (h * 0.45 + 5);
        path.lineTo(min(x, w), y);
      }
      final flick = 0.45 + rng.nextDouble() * 0.55;
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = const Color(0xFF3FD0FF).withValues(alpha: 0.35 * flick)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white.withValues(alpha: flick));
    }
  }

  @override
  bool shouldRepaint(_Lightning o) => (o.v * 16).floor() != (v * 16).floor();
}

/// 🔥 ١٢ — ژمارا کۆمبۆیێ ل تەنشت خەتێ
class ComboBadge extends StatelessWidget {
  final int combo;
  const ComboBadge({super.key, required this.combo});

  @override
  Widget build(BuildContext context) {
    final tier = comboTier(combo);
    final color = switch (tier) { 2 => const Color(0xFF3FD0FF), 1 => const Color(0xFF7BE22B), _ => AppColors.orange };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: c),
      child: combo < 3
          ? const SizedBox(key: ValueKey('none'), width: 0)
          : Container(
              key: ValueKey(combo),
              margin: const EdgeInsetsDirectional.only(start: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Text('${tier == 0 ? '🔥' : '⚡'}$combo',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
    );
  }
}

// ───────────────────────── «+٤ XP» ─────────────────────────
void showXpPop(BuildContext context, int xp, {int combo = 0}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null || xp <= 0) return;
  late OverlayEntry e;
  e = OverlayEntry(builder: (_) => _XpPop(xp: xp, combo: combo, onDone: () => e.remove()));
  overlay.insert(e);
}

class _XpPop extends StatefulWidget {
  final int xp, combo;
  final VoidCallback onDone;
  const _XpPop({required this.xp, required this.combo, required this.onDone});
  @override
  State<_XpPop> createState() => _XpPopState();
}

class _XpPopState extends State<_XpPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward().whenComplete(widget.onDone);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 62;
    final color = switch (comboTier(widget.combo)) { 2 => const Color(0xFF3FD0FF), 1 => const Color(0xFF7BE22B), _ => AppColors.gold };
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            return Opacity(
              opacity: t < 0.7 ? 1 : (1 - (t - 0.7) / 0.3),
              child: Transform.translate(
                offset: Offset(0, -28 * Curves.easeOut.transform(t)),
                child: Transform.scale(
                  scale: 0.6 + 0.5 * Curves.elasticOut.transform(min(1, t * 2)),
                  child: Center(
                    child: Text(RewardsService.instance.xpMultiplier > 1
                        ? '+${widget.xp * RewardsService.instance.xpMultiplier} XP ⚡×${RewardsService.instance.xpMultiplier}'
                        : '+${widget.xp} XP',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: color,
                          shadows: [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 12)],
                        )),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── 🦸 هەر ٥ بەرسڤان ─────────────────────────
String comboMessage(int n, AppLanguage lang) {
  final r = Random();
  String pick(List<String> l) => l[r.nextInt(l.length)];
  if (lang != AppLanguage.badini) {
    final en = lang == AppLanguage.english;
    if (n == 10) return en ? '$n in a row! ⚡ Now every answer = 4 XP' : '$n am Stück! ⚡ Jetzt 4 XP pro Antwort';
    if (n == 25) return en ? '$n in a row! 🚀 Now 5 XP per answer' : '$n am Stück! 🚀 Jetzt 5 XP pro Antwort';
    if (n == 50) return en ? '$n in a row! 👑 Now 7 XP per answer' : '$n am Stück! 👑 Jetzt 7 XP pro Antwort';
    return en ? pick(['$n correct in a row! 🔥', 'You are on fire! $n 🔥', 'Unstoppable! $n in a row ⚡'])
        : pick(['$n richtig am Stück! 🔥', 'Du bist on fire! $n 🔥', 'Unaufhaltsam! $n am Stück ⚡']);
  }
  final k = kuNum(n);
  if (n == 10) return 'واو! $k بەرسڤ بێ خەلەتی ⚡\nژ نوکە هەر بەرسڤەک = ٤ XP';
  if (n == 25) return '$k ل سەر ئێک! 🚀\nژ نوکە هەر بەرسڤەک = ٥ XP';
  if (n == 50) return '$k بێ خەلەتی! 👑 تو شاهێ ئەلمانیێ یی\nهەر بەرسڤەک = ٧ XP';
  if (n == 5) {
    return pick([
      '$k بەرسڤ ل دویڤ ئێک — بێ ئێک خەلەتی! 🔥',
      'تو مرۆڤەکێ زیرەکی! 🧠 $k بێ خەلەتی',
      'ئافەرین! $k ل سەر ئێک دروست ✨',
    ]);
  }
  if (n == 15) {
    return pick([
      'وەڵڵاهـ تو ئەڤرۆ نە ئاساییی! 🤯\n$k بەرسڤ بێ خەلەتی',
      'تو بوویە قارەمان! 🦸 $k ل سەر ئێک',
    ]);
  }
  return pick([
    'وەڵڵاهـ تو ئەڤرۆ نە ئاساییی! 🤯 $k بێ خەلەتی',
    'قارەمان! 🦸 $k بەرسڤ ل دویڤ ئێک',
    'کەس نەشێت تە راوەستینیت! ⚡ $k',
    'مێشکێ تە کۆمپیوتەرە! 🧠 $k بێ خەلەتی',
    'ئەڤە ئاستێ پرۆفیشناڵانە یە 🏆 $k ل سەر ئێک',
  ]);
}

/// هەر ٥ بەرسڤێن دروست ل دویڤ ئێک: پەیامەک + کاریکاتێر (١٠، ١٥، … ب شێوێ قارەمانی دفڕیت / ژ ئەسمانی دکەڤیت)
void showComboToast(BuildContext context, int combo, AppLanguage lang) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  // ١٠ و پاشان: هەر جار شێوەیەکێ دی
  final style = combo < 10 ? _HeroStyle.cheer : _HeroStyle.values[1 + (combo ~/ 5) % 3];
  late OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => _ComboToast(
      combo: combo,
      text: comboMessage(combo, lang),
      style: style,
      rtl: lang.direction == TextDirection.rtl,
      onDone: () => e.remove(),
    ),
  );
  overlay.insert(e);
}

enum _HeroStyle { cheer, fly, drop, power }

class _ComboToast extends StatefulWidget {
  final int combo;
  final String text;
  final _HeroStyle style;
  final bool rtl;
  final VoidCallback onDone;
  const _ComboToast({required this.combo, required this.text, required this.style, required this.rtl, required this.onDone});
  @override
  State<_ComboToast> createState() => _ComboToastState();
}

class _ComboToastState extends State<_ComboToast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2900))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top + 70;
    final tier = comboTier(widget.combo);
    final accent = switch (tier) { 2 => const Color(0xFF3FD0FF), 1 => const Color(0xFF58CC02), _ => AppColors.orange };
    final char = MascotChar.forUser();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          // بانەر: ژ ژۆر دهێت، دمینیت، دچیت
          final inT = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
          final outT = Curves.easeIn.transform(((t - 0.85) / 0.15).clamp(0.0, 1.0));
          final bannerY = -140 + 140 * inT - 160 * outT;
          return Stack(children: [
            // فلاشا رەنگین ل دۆرا شاشێ
            if (tier > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: (0.35 * (1 - (t / 0.25).clamp(0.0, 1.0))),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [Colors.transparent, accent.withValues(alpha: 0.9)], radius: 1.1),
                    ),
                  ),
                ),
              ),
            if (widget.style != _HeroStyle.cheer) _hero(t, size, char, accent),
            Positioned(
              top: top + bannerY,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color.lerp(const Color(0xFF16232A), accent, 0.25)!,
                      const Color(0xFF16232A),
                    ]),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accent, width: 2),
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 18)],
                  ),
                  child: Row(textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr, children: [
                    if (widget.style == _HeroStyle.cheer)
                      SizedBox(width: 64, height: 76, child: MascotView(char: char, mood: MascotMood.happy, height: 76, lipSync: false))
                    else
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.2), border: Border.all(color: accent, width: 2)),
                        child: Text(kuNum(widget.combo), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: accent)),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.text,
                        textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  /// 🦸 کاریکاتێر وەکی قارەمانی
  Widget _hero(double t, Size size, MascotChar char, Color accent) {
    const h = 150.0;
    final img = Image.asset(widget.style == _HeroStyle.fly ? char.flyFull : (widget.style == _HeroStyle.drop ? char.landFull : char.happyFull), height: h);
    switch (widget.style) {
      case _HeroStyle.fly:
        // ژ لایەکی دفڕیت بۆ لایێ دی ب کەپ و خەتێن لەزێ
        final p = Curves.easeInOutSine.transform((t / 0.8).clamp(0.0, 1.0));
        final x = -h + (size.width + 2 * h) * p;
        final y = size.height * 0.42 - 60 * sin(p * pi);
        return Positioned(
          left: x - h / 2,
          top: y,
          child: Opacity(
            opacity: t > 0.8 ? 0 : 1,
            child: Transform.rotate(
              angle: 0,
              child: Stack(clipBehavior: Clip.none, children: [
                // خەتێن لەزێ + سێبەرێن ل دویڤ (motion trail)
                Positioned(left: -h * 1.1, top: h * 0.1, child: CustomPaint(size: Size(h * 1.1, h * 0.8), painter: _SpeedLines(t, accent))),
                for (var k = 3; k >= 1; k--)
                  Positioned(
                    left: -k * 26.0,
                    top: k * 6.0,
                    child: Opacity(
                      opacity: 0.12 * (4 - k),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(accent, BlendMode.srcATop),
                        child: Image.asset(char.flyFull, height: h),
                      ),
                    ),
                  ),
                img,
              ]),
            ),
          ),
        );
      case _HeroStyle.drop:
        // ژ ئەسمانی دکەڤیت، دگەهیتە ئەردی، تۆز
        final fall = Curves.easeIn.transform((t / 0.28).clamp(0.0, 1.0));
        final land = ((t - 0.28) / 0.2).clamp(0.0, 1.0);
        final squash = land > 0 ? 1 - 0.12 * sin(land * pi) : 1.0;
        final y = -h + (size.height * 0.5) * fall;
        return Positioned(
          left: size.width / 2 - h * 0.4,
          top: y,
          child: Opacity(
            opacity: t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
              if (land > 0)
                Positioned(
                  bottom: -10,
                  child: Opacity(
                    opacity: 1 - land,
                    child: Container(
                      width: h * (0.8 + land),
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: RadialGradient(colors: [accent.withValues(alpha: 0.8), Colors.transparent]),
                      ),
                    ),
                  ),
                ),
              Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(1 + (1 - squash), squash, 1),
                child: img,
              ),
            ]),
          ),
        );
      case _HeroStyle.power:
        // وەکی Iron Man: بازنەیێن هێزێ و برووسک ل دۆر
        final a = Curves.easeOutBack.transform((t / 0.25).clamp(0.0, 1.0));
        return Positioned(
          left: size.width / 2 - h * 0.45,
          top: size.height * 0.4,
          child: Opacity(
            opacity: t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1,
            child: Transform.scale(
              scale: 0.3 + 0.7 * a,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                CustomPaint(size: const Size(h * 1.3, h * 1.3), painter: _PowerRings(t, accent)),
                img,
              ]),
            ),
          ),
        );
      case _HeroStyle.cheer:
        return const SizedBox.shrink();
    }
  }
}

class _SpeedLines extends CustomPainter {
  final double t;
  final Color accent;
  _SpeedLines(this.t, this.accent);
  @override
  void paint(Canvas canvas, Size s) {
    for (var k = 0; k < 6; k++) {
      final y = s.height * (0.08 + k * 0.16);
      final len = s.width * (0.35 + 0.5 * (((k * 37 + (t * 30).floor()) % 10) / 10));
      final paint = Paint()
        ..strokeWidth = k.isEven ? 3 : 2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [Colors.transparent, (k.isEven ? Colors.white : accent).withValues(alpha: 0.8)])
            .createShader(Rect.fromLTWH(s.width - len, y - 2, len, 4));
      canvas.drawLine(Offset(s.width - len, y), Offset(s.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_SpeedLines o) => o.t != t;
}

class _PowerRings extends CustomPainter {
  final double t;
  final Color accent;
  _PowerRings(this.t, this.accent);
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    for (var k = 0; k < 3; k++) {
      final p = ((t * 2.2 + k / 3) % 1);
      canvas.drawCircle(
          c,
          s.width * 0.25 + s.width * 0.4 * p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - p) + 1
            ..color = accent.withValues(alpha: 0.9 * (1 - p)));
    }
    final rng = Random((t * 18).floor());
    for (var b = 0; b < 4; b++) {
      final ang = rng.nextDouble() * 2 * pi;
      var r = s.width * 0.3;
      final path = Path()..moveTo(c.dx + cos(ang) * r, c.dy + sin(ang) * r);
      for (var j = 0; j < 4; j++) {
        r += s.width * 0.06;
        final a2 = ang + (rng.nextDouble() - 0.5) * 0.5;
        path.lineTo(c.dx + cos(a2) * r, c.dy + sin(a2) * r);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.9));
    }
  }

  @override
  bool shouldRepaint(_PowerRings o) => o.t != t;
}


/// 🧪 ?demo=toast — پشکنینا پەیامێن کۆمبۆیێ
class ToastDemo extends StatefulWidget {
  const ToastDemo({super.key});
  @override
  State<ToastDemo> createState() => _ToastDemoState();
}

class _ToastDemoState extends State<ToastDemo> {
  @override
  void initState() {
    super.initState();
    var k = 0;
    const seq = [5, 10, 15, 20];
    void next() {
      if (!mounted) return;
      showComboToast(context, seq[k % seq.length], AppLanguage.badini);
      k++;
      Future.delayed(const Duration(milliseconds: 3200), next);
    }

    Future.delayed(const Duration(milliseconds: 500), next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const ComboBar(value: 0.6, combo: 16)),
        body: const Center(child: Text('toast demo')),
      );
}
