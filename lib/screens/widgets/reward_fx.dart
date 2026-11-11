import 'dart:math';

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/progress_service.dart';
import '../../services/rewards_service.dart';
import '../../services/sfx.dart';
import '../../ui.dart';

/// 🎬 ئەنیمەیشنێن خەلاتان: ئاگرێ زیندی، قەشابوون، شکاندنا قەشایێ، دویکێل، و فڕینا دیناران.
/// هەمی ب وێنەیێن ASP (assets/img/fx) — نە ئیمۆجی.

const _fx = 'assets/img/fx';

/// 🪙 جهێ دیناران ل سەری (بۆ فڕینا دیناران)
final GlobalKey dinarTargetKey = GlobalKey(debugLabel: 'dinar');

/// دەمێ ب خۆ (چرکە) بۆ ئەنیمەیشنێن بێ دویماهی
mixin _Clock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  double get secs => clock.value * 60;
  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }
}

// ───────────────────────── 🔥 ئاگرێ زیندی ─────────────────────────

class RealFire extends StatefulWidget {
  final double size;
  final bool sparks;
  final double intensity; // 0..1 (بۆ ڤەمرینێ)
  const RealFire({super.key, this.size = 120, this.sparks = true, this.intensity = 1});

  @override
  State<RealFire> createState() => _RealFireState();
}

class _RealFireState extends State<RealFire> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: clock,
        builder: (_, __) {
          final t = secs;
          final k = widget.intensity.clamp(0.0, 1.0);
          final sy = (1 + 0.06 * sin(t * 7.3) + 0.035 * sin(t * 13.7 + 1.3)) * (0.35 + 0.65 * k);
          final sx = 1 + 0.035 * sin(t * 5.1 + 0.7);
          final skew = 0.045 * sin(t * 3.3) + 0.02 * sin(t * 9.1);
          final glow = 0.55 + 0.15 * sin(t * 6.1) + 0.1 * sin(t * 11.3);
          return Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
            // ✨ رۆناهیا بنی
            Positioned(
              bottom: s * 0.02,
              child: Container(
                width: s * 0.9,
                height: s * 0.32,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    const Color(0xFFFFB347).withValues(alpha: glow * k),
                    const Color(0xFFFF6A00).withValues(alpha: 0.25 * glow * k),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(sx, sy, 1)..setEntry(0, 1, skew),
              child: Stack(alignment: Alignment.bottomCenter, children: [
                Image.asset('$_fx/fire.webp', width: s, height: s, fit: BoxFit.contain, opacity: AlwaysStoppedAnimation(k)),
                // کۆپیەکا زڤڕاندی ب ڕۆهنیا گوهۆڕ ➔ ئاگر دلڤلڤیت
                Transform.flip(
                  flipX: true,
                  child: Transform.scale(
                    alignment: Alignment.bottomCenter,
                    scaleY: 0.92 + 0.08 * sin(t * 4.7 + 2),
                    child: Image.asset('$_fx/fire.webp',
                        width: s,
                        height: s,
                        fit: BoxFit.contain,
                        opacity: AlwaysStoppedAnimation((0.28 + 0.2 * sin(t * 5.3)) * k)),
                  ),
                ),
              ]),
            ),
            if (widget.sparks && k > 0.3)
              Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _SparksPainter(t, k)))),
          ]);
        },
      ),
    );
  }
}

class _SparksPainter extends CustomPainter {
  final double t, k;
  _SparksPainter(this.t, this.k);
  static final _seeds = List.generate(16, (i) => (Random(i * 97 + 3).nextDouble(), Random(i * 31 + 7).nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    for (final (a, b) in _seeds) {
      final speed = 0.35 + 0.5 * b;
      final ph = (t * speed + a * 7) % 1.0; // 0 ➔ 1 ژ بنی بۆ سەری
      final x = size.width * (0.5 + (a - 0.5) * 0.55 + 0.08 * sin(t * (2 + b * 3) + a * 9) * ph);
      final y = size.height * (0.85 - ph * 0.95);
      final alpha = (1 - ph) * (ph < 0.1 ? ph * 10 : 1) * k;
      p.color = Color.lerp(const Color(0xFFFFE08A), const Color(0xFFFF5A00), ph)!.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), (1.2 + 1.6 * b) * (1 - ph * 0.5) * size.width / 120, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SparksPainter old) => true;
}

// ───────────────────────── 🧊 ئاگر ➔ نیڤ قەشا ➔ قەشا ─────────────────────────

class FreezeAnim extends StatefulWidget {
  final double size;
  const FreezeAnim({super.key, this.size = 220});
  @override
  State<FreezeAnim> createState() => _FreezeAnimState();
}

class _FreezeAnimState extends State<FreezeAnim> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b) => Curves.easeInOut.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final t = c.value;
          final half = _seg(t, 0.18, 0.45);
          final block = _seg(t, 0.48, 0.72);
          final flash = t > 0.5 && t < 0.7 ? sin((t - 0.5) / 0.2 * pi) : 0.0;
          final bounce = block > 0 ? 1 + 0.08 * sin(block * pi) : 1.0;
          return Stack(alignment: Alignment.bottomCenter, children: [
            Opacity(opacity: (1 - half).clamp(0.0, 1.0), child: RealFire(size: s, intensity: 1 - half * 0.6)),
            Opacity(
              opacity: (half * (1 - block)).clamp(0.0, 1.0),
              child: Image.asset('$_fx/fire_half_ice.webp', width: s, height: s),
            ),
            Opacity(
              opacity: block,
              child: Transform.scale(
                scale: bounce,
                alignment: Alignment.bottomCenter,
                child: Image.asset('$_fx/ice_block.webp', width: s, height: s),
              ),
            ),
            // ❄️ دەنکێن بەفرێ بەرەڤ ناڤەراستێ
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _FrostPainter(t)))),
            if (flash > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.7 * flash), Colors.transparent]),
                    ),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _FrostPainter extends CustomPainter {
  final double t;
  _FrostPainter(this.t);
  static final _r = List.generate(26, (i) => (Random(i * 13 + 1).nextDouble(), Random(i * 7 + 5).nextDouble()));
  @override
  void paint(Canvas canvas, Size size) {
    if (t < 0.12 || t > 0.8) return;
    final k = ((t - 0.12) / 0.68).clamp(0.0, 1.0);
    final c = Offset(size.width / 2, size.height * 0.6);
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (final (a, b) in _r) {
      final ang = a * 2 * pi;
      final d = size.width * (0.75 - 0.6 * ((k + b * 0.4) % 1.0));
      final pos = c + Offset(cos(ang) * d, sin(ang) * d * 0.8);
      p.color = const Color(0xFFCFF3FF).withValues(alpha: 0.9 * sin(k * pi));
      canvas.drawCircle(pos, 1.5 + 2 * b, p);
    }
  }

  @override
  bool shouldRepaint(covariant _FrostPainter old) => old.t != t;
}

// ───────────────────────── 💥 شکاندنا قەشایێ (Streak هاتە پاراستن) ─────────────────────────

class ShatterAnim extends StatefulWidget {
  final double size;
  const ShatterAnim({super.key, this.size = 220});
  @override
  State<ShatterAnim> createState() => _ShatterAnimState();
}

class _ShatterAnimState extends State<ShatterAnim> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final t = c.value;
          final shake = t < 0.3 ? sin(t * 120) * 5 * (t / 0.3) : 0.0;
          final burst = ((t - 0.3) / 0.4).clamp(0.0, 1.0);
          final fireIn = Curves.easeOut.transform(((t - 0.42) / 0.35).clamp(0.0, 1.0));
          return Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
            if (t < 0.34)
              Transform.translate(offset: Offset(shake, 0), child: Image.asset('$_fx/ice_block.webp', width: s, height: s)),
            if (burst > 0 && burst < 1)
              Opacity(
                opacity: (1 - burst).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.95 + 0.25 * burst,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset('$_fx/ice_shatter.webp', width: s, height: s),
                ),
              ),
            if (fireIn > 0) Opacity(opacity: fireIn, child: RealFire(size: s * (0.7 + 0.3 * fireIn))),
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ShardsPainter(burst)))),
          ]);
        },
      ),
    );
  }
}

class _ShardsPainter extends CustomPainter {
  final double k;
  _ShardsPainter(this.k);
  static final _r = List.generate(18, (i) {
    final r = Random(i * 41 + 11);
    return (r.nextDouble() * 2 * pi, 0.5 + r.nextDouble(), r.nextDouble() * 6 - 3, 6 + r.nextDouble() * 10);
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (k <= 0 || k >= 1) return;
    final c = Offset(size.width / 2, size.height * 0.55);
    for (final (ang, sp, rot, sz) in _r) {
      final d = size.width * 0.75 * sp * Curves.easeOut.transform(k);
      final pos = c + Offset(cos(ang) * d, sin(ang) * d * 0.7 + 160 * k * k);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rot * k);
      final path = Path()
        ..moveTo(0, -sz)
        ..lineTo(sz * 0.6, sz * 0.4)
        ..lineTo(-sz * 0.5, sz * 0.7)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFBDEBFF).withValues(alpha: (1 - k) * 0.9));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: 1 - k));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShardsPainter old) => old.k != k;
}

// ───────────────────────── 💨 دویکێل (Streak چوو) ─────────────────────────

class SmokeAnim extends StatefulWidget {
  final double size;
  const SmokeAnim({super.key, this.size = 220});
  @override
  State<SmokeAnim> createState() => _SmokeAnimState();
}

class _SmokeAnimState extends State<SmokeAnim> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final t = c.value;
          final die = Curves.easeIn.transform((t / 0.45).clamp(0.0, 1.0));
          final smoke = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
          return Stack(alignment: Alignment.bottomCenter, children: [
            if (die < 1) RealFire(size: s, intensity: 1 - die, sparks: die < 0.5),
            Opacity(
              opacity: (sin(smoke * pi) * 0.95).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(6 * sin(smoke * 5), -50 * smoke),
                child: Transform.scale(
                  scale: 0.85 + 0.4 * smoke,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset('$_fx/smoke.webp', width: s, height: s),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ───────────────────────── 🪙 فڕینا دیناران ─────────────────────────

void flyCoins(BuildContext context, int amount, {Offset? from}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || amount <= 0) return;
  final size = MediaQuery.sizeOf(context);
  final start = from ?? Offset(size.width / 2, size.height / 2);
  var target = Offset(size.width - 60, 40);
  final box = dinarTargetKey.currentContext?.findRenderObject();
  if (box is RenderBox && box.hasSize && box.attached) {
    target = box.localToGlobal(box.size.center(Offset.zero));
  }
  final n = (amount / 5).ceil().clamp(4, 12);
  final rng = Random();
  for (var i = 0; i < n; i++) {
    late OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => _FlyingCoin(
        start: start + Offset(rng.nextDouble() * 60 - 30, rng.nextDouble() * 40 - 20),
        end: target,
        delay: Duration(milliseconds: 70 * i),
        bend: rng.nextDouble() * 160 - 80,
        onDone: () {
          e.remove();
          if (i == 0) Sfx.star();
        },
      ),
    );
    overlay.insert(e);
  }
}

class _FlyingCoin extends StatefulWidget {
  final Offset start, end;
  final Duration delay;
  final double bend;
  final VoidCallback onDone;
  const _FlyingCoin({required this.start, required this.end, required this.delay, required this.bend, required this.onDone});
  @override
  State<_FlyingCoin> createState() => _FlyingCoinState();
}

class _FlyingCoinState extends State<_FlyingCoin> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) c.forward().whenComplete(widget.onDone);
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final t = Curves.easeInCubic.transform(c.value);
        final a = widget.start, b = widget.end;
        final ctrl = Offset((a.dx + b.dx) / 2 + widget.bend, min(a.dy, b.dy) - 120);
        final p = a * (1 - t) * (1 - t) + ctrl * 2 * t * (1 - t) + b * t * t;
        final sz = 38 * (1 - 0.45 * t);
        return Positioned(
          left: p.dx - sz / 2,
          top: p.dy - sz / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: c.value == 0 ? 0 : 1,
              child: Transform.rotate(
                angle: t * 6,
                child: Image.asset('$_fx/coin_s.webp', width: sz, height: sz),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── 🎁 نیشاندانا خەلاتان ─────────────────────────

bool _showing = false;

/// هەمی خەلاتێن چاڤەڕێ نیشان بدە (پشتی وانێ، ل ماڵێ، پشتی کڕینێ)
Future<void> showPendingRewards(BuildContext context) async {
  if (_showing) return;
  _showing = true;
  try {
    while (context.mounted) {
      final ev = RewardsService.instance.takeEvent();
      if (ev == null) break;
      await _showEvent(context, ev);
      final coins = ev.rewards.where((r) => r.kind == RewardKind.dinar && r.amount > 0).fold<int>(0, (s, r) => s + r.amount);
      if (coins > 0 && context.mounted) {
        flyCoins(context, coins);
        await Future.delayed(const Duration(milliseconds: 900));
      }
    }
  } finally {
    _showing = false;
  }
}

Future<void> _showEvent(BuildContext context, RewardEvent ev) {
  final n = ProgressService.instance.nativeLang;
  final dark = ev.fx != FxKind.reward;
  Widget art = switch (ev.fx) {
    FxKind.freezeBought => const FreezeAnim(),
    FxKind.streakSaved => const ShatterAnim(),
    FxKind.streakLost => const SmokeAnim(),
    FxKind.reward => _rewardArt(ev),
  };
  if (ev.fx == FxKind.reward) Sfx.done();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'reward',
    barrierColor: Colors.black.withValues(alpha: dark ? 0.85 : 0.6),
    transitionDuration: const Duration(milliseconds: 380),
    transitionBuilder: (_, a, __, child) => Transform.scale(
      scale: 0.7 + 0.3 * Curves.easeOutBack.transform(a.value),
      child: Opacity(opacity: a.value, child: child),
    ),
    pageBuilder: (ctx, _, __) => Directionality(
      textDirection: n.direction,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: min(MediaQuery.sizeOf(ctx).width - 40, 380),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [Color(0xFF0E1A24), Color(0xFF05090D)]
                    : const [Color(0xFF3A2A06), Color(0xFF1A1206)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: (dark ? const Color(0xFF7FD3FF) : AppColors.gold).withValues(alpha: 0.6), width: 2),
              boxShadow: [BoxShadow(color: (dark ? const Color(0xFF4FC3F7) : AppColors.gold).withValues(alpha: 0.35), blurRadius: 40)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              art,
              const SizedBox(height: 10),
              Text(ev.title(n),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white, height: 1.4)),
              const SizedBox(height: 10),
              for (final r in ev.rewards)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset(
                        switch (r.kind) {
                          RewardKind.dinar => '$_fx/coin_s.webp',
                          RewardKind.boost => '$_fx/${r.amount >= 3 ? 'boost_gold' : 'boost_blue'}.webp',
                          RewardKind.freeze => '$_fx/freeze_cube.webp',
                        },
                        width: 30,
                        height: 30),
                    const SizedBox(width: 8),
                    Text(r.label(n),
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: r.kind == RewardKind.dinar && r.amount < 0 ? AppColors.red : const Color(0xFFFFD54F))),
                  ]),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: dark ? const Color(0xFF1CB0F6) : AppColors.gold,
                    foregroundColor: dark ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr(n, 'باشە', 'OK', 'OK'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}

Widget _rewardArt(RewardEvent ev) {
  final r = ev.rewards.isEmpty ? null : ev.rewards.first;
  final img = switch (r?.kind) {
    RewardKind.boost => (r!.amount >= 3 ? 'boost_gold' : 'boost_blue'),
    RewardKind.freeze => 'freeze_cube',
    _ => (r != null && r.amount >= 50) ? 'chest' : (ev.emoji == '🎁' ? 'gift' : 'coin_stack'),
  };
  return _Pop(child: Image.asset('$_fx/$img.webp', width: 150, height: 150));
}

/// گەشبوونا وێنەی دگەل تیشکان
class _Pop extends StatefulWidget {
  final Widget child;
  const _Pop({required this.child});
  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 180,
      child: AnimatedBuilder(
        animation: clock,
        builder: (_, child) {
          final t = secs;
          final inT = Curves.elasticOut.transform((t / 1.1).clamp(0.0, 1.0));
          return Stack(alignment: Alignment.center, children: [
            Transform.rotate(
              angle: t * 0.4,
              child: CustomPaint(size: const Size(210, 210), painter: _RaysPainter()),
            ),
            Transform.translate(
              offset: Offset(0, 4 * sin(t * 2.4)),
              child: Transform.scale(scale: 0.3 + 0.7 * inT, child: child),
            ),
          ]);
        },
        child: widget.child,
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..shader = RadialGradient(colors: [const Color(0x66FFD54F), const Color(0x00FFD54F)])
          .createShader(Rect.fromCircle(center: c, radius: size.width / 2));
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a - 0.12) * size.width / 2, c.dy + sin(a - 0.12) * size.width / 2)
        ..lineTo(c.dx + cos(a + 0.12) * size.width / 2, c.dy + sin(a + 0.12) * size.width / 2)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 🪙 چیپا دیناران ل سەری (جهێ گوهۆڕینا زمانی یا بەرێ)
class DinarChip extends StatelessWidget {
  final VoidCallback? onTap;
  final bool target; // تنێ ئێک جار ل سەر شاشێ (GlobalKey)
  const DinarChip({super.key, this.onTap, this.target = false});

  @override
  Widget build(BuildContext context) {
    final r = RewardsService.instance;
    return ListenableBuilder(
      listenable: r,
      builder: (_, __) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('$_fx/coin_s.webp', key: target ? dinarTargetKey : null, width: 24, height: 24),
            const SizedBox(width: 4),
            Text('${r.dinar}', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.goldText)),
            if (r.boostActive) ...[
              const SizedBox(width: 4),
              Text('⚡×${r.xpMultiplier}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.blue)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// 🔥 ئاگرێ بچووک یێ Streak ل سەری (ب قەشا ئەگەر پاراستن هەبیت)
class StreakFlame extends StatelessWidget {
  final int streak;
  final double size;
  const StreakFlame({super.key, required this.streak, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final r = RewardsService.instance;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: size,
        height: size,
        child: streak > 0
            ? RealFire(size: size, sparks: false)
            : Opacity(opacity: 0.45, child: Image.asset('$_fx/fire.webp', width: size, height: size, color: Colors.grey, colorBlendMode: BlendMode.saturation)),
      ),
      const SizedBox(width: 3),
      Text('$streak', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange)),
      if (r.freezes > 0) ...[
        const SizedBox(width: 2),
        Image.asset('$_fx/freeze_cube.webp', width: 14, height: 14),
      ],
    ]);
  }
}
