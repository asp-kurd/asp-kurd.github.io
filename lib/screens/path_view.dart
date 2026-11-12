import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../data/path.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/rewards_service.dart';
import '../ui.dart';
import '../data/pronouns.dart';
import 'course_screens.dart';
import 'exam_coin.dart';
import 'grammar_screen.dart';
import 'lesson_screen.dart';
import 'widgets/combo.dart' show kuNum;

/// 🛤️ رێکا فێربوونێ یا نوو (asp 2.22): شێوە ب ژمارا کۆرسان (٣ ➔ سێگۆشە … ٦ ➔ شەشگۆشە)،
/// هەر کۆرسەک لایەکێ شێوەی پڕ دکەت، ئەلقەیا پێشکەفتنێ ل دۆر وانەیا نوکە، و زێڕ پشتی دووبارەکرنێ.

// ═══════════════════════ رەنگ ═══════════════════════
Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;
Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;

const _maroon = Color(0xFF9E1F36);
const _maroonDark = Color(0xFF4E0A16);
const _goldLip = Color(0xFF8C5E07);

enum NodeState { locked, open, done, gold }

/// چێکرنا شێوەیێ (ب کونجێن نەرم)
Path polyPath(int n, Offset c, double r, {double round = 0.2}) {
  if (n < 3) return Path()..addOval(Rect.fromCircle(center: c, radius: r)); // ⭕ بازنە
  final pts = polyPoints(n, c, r);
  final p = Path();
  for (var i = 0; i < n; i++) {
    final v = pts[i], prev = pts[(i - 1 + n) % n], next = pts[(i + 1) % n];
    final a = Offset.lerp(v, prev, round)!, b = Offset.lerp(v, next, round)!;
    if (i == 0) {
      p.moveTo(a.dx, a.dy);
    } else {
      p.lineTo(a.dx, a.dy);
    }
    p.quadraticBezierTo(v.dx, v.dy, b.dx, b.dy);
  }
  p.close();
  return p;
}

List<Offset> polyPoints(int n, Offset c, double r) {
  // ژمارا جووت ➔ سەرێ راست (چارگۆشە/شەشگۆشە)؛ تاک ➔ سەرێ تیژ (سێگۆشە/پێنجگۆشە)
  final start = -pi / 2 + (n.isEven ? pi / n : 0);
  return [for (var i = 0; i < n; i++) c + Offset(cos(start + 2 * pi * i / n), sin(start + 2 * pi * i / n)) * r];
}

/// سێگۆشە ب چاڤ بچووکترە ➔ کەمەکێ مەزنتر و نزمتر
(Offset, double) _fit(int n, Offset c, double r) => switch (n) {
      3 => (c + Offset(0, r * 0.16), r * 1.2),
      4 => (c, r * 1.04),
      _ => (c, r),
    };

/// ئەلقەیا پێشکەفتنێ ب شێوێ وانێ — ژ سەری دەستپێدکەت و ب ئاراستەیا دەمژمێرێ دچیت
Path ringPath(int n, Offset c, double r) {
  if (n < 3) return Path()..addArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi - 0.001);
  final pts = polyPoints(n, c, r);
  const round = 0.2;
  Offset a(int i) => Offset.lerp(pts[i % n], pts[(i - 1 + n) % n], round)!;
  Offset b(int i) => Offset.lerp(pts[i % n], pts[(i + 1) % n], round)!;
  final p = Path();
  if (n.isEven) {
    final mid = Offset.lerp(pts[n - 1], pts[0], 0.5)!;
    p.moveTo(mid.dx, mid.dy);
    for (var i = 0; i < n; i++) {
      p.lineTo(a(i).dx, a(i).dy);
      p.quadraticBezierTo(pts[i].dx, pts[i].dy, b(i).dx, b(i).dy);
    }
    p.lineTo(mid.dx, mid.dy);
  } else {
    final st = b(0);
    p.moveTo(st.dx, st.dy);
    for (var i = 1; i <= n; i++) {
      final k = i % n;
      p.lineTo(a(k).dx, a(k).dy);
      p.quadraticBezierTo(pts[k].dx, pts[k].dy, b(k).dx, b(k).dy);
    }
  }
  return p;
}

// ═══════════════════════ وێنەکێشانا شێوەیی ═══════════════════════
class ShapePainter extends CustomPainter {
  final int sides, filled;
  final NodeState state;
  final Color color;
  final bool boost, current, pressed;
  final double t; // ٠..١ ئەنیمەیشن
  final double ring; // ٠..١ پێشکەفتن (تنێ بۆ وانەیا نوکە) یان -1
  final double outline; // ٠..١ هێلا گرێدای ل دەرڤە (وانەیا تەمام)
  ShapePainter({
    required this.sides,
    required this.filled,
    required this.state,
    required this.color,
    this.boost = false,
    this.current = false,
    this.pressed = false,
    this.t = 0,
    this.ring = -1,
    this.outline = 0,
    super.repaint,
  });

  static const lipH = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c0 = Offset(size.width / 2, size.height / 2 - lipH / 2);
    final r0 = size.width * 0.30;
    final (c, r) = _fit(sides, c0, r0);
    final dy = pressed ? lipH - 2 : 0.0;

    // ── ئەلقەیا پێشکەفتنێ ──
    if (ring >= 0) {
      final rp = ringPath(sides, c + const Offset(0, lipH / 2), r * 1.42);
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.lockFace;
      canvas.drawPath(rp, track);
      if (ring > 0) {
        final prog = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = boost ? const Color(0xFFE0405E) : (state == NodeState.gold ? const Color(0xFFFFC93C) : _lighten(color, 0.08));
        for (final m in rp.computeMetrics()) {
          canvas.drawPath(m.extractPath(0, m.length * ring.clamp(0, 1)), prog);
        }
      }
    }

    // ── هالەیا بووستێ (سۆرێ مەیی) ──
    if (boost && state != NodeState.locked) {
      final glow = Paint()
        ..shader = ui.Gradient.radial(c, r * 2.1, [const Color(0xFFE0405E).withValues(alpha: current ? 0.55 : 0.28), Colors.transparent]);
      canvas.drawCircle(c, r * 2.1, glow);
    }
    if (state == NodeState.gold) {
      final glow = Paint()..shader = ui.Gradient.radial(c, r * 1.9, [const Color(0xFFFFD54F).withValues(alpha: 0.35), Colors.transparent]);
      canvas.drawCircle(c, r * 1.9, glow);
    }

    final face = polyPath(sides, c + Offset(0, dy), r);
    final lip = polyPath(sides, c + const Offset(0, lipH), r);

    // ── رەنگ ──
    late Color lipC;
    late Paint faceP;
    final rect = Rect.fromCircle(center: c + Offset(0, dy), radius: r);
    switch (state) {
      case NodeState.locked:
        lipC = AppColors.lockLip;
        faceP = Paint()..color = AppColors.lockFace;
      case NodeState.gold:
        lipC = _goldLip;
        faceP = Paint()
          ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, const [
            Color(0xFFFFF6C8),
            Color(0xFFFFD84D),
            Color(0xFFE9A920),
            Color(0xFFFFE27A),
            Color(0xFFC88A12),
          ], const [0, 0.28, 0.55, 0.75, 1]);
      case NodeState.open || NodeState.done:
        if (boost) {
          lipC = _maroonDark;
          faceP = Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, const [Color(0xFFD23A57), _maroon, Color(0xFF7A1528)], const [0, 0.5, 1]);
        } else {
          lipC = _darken(color, 0.32);
          faceP = Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [_lighten(color, 0.12), color, _darken(color, 0.06)], const [0, 0.55, 1]);
        }
    }
    canvas.drawPath(lip, Paint()..color = lipC);
    canvas.drawPath(face, faceP);

    // ── لایێن شێوەی: هەر کۆرسەکا تەمامکری لایەکێ رۆهن دکەت ──
    // ✅ وانە تەمام بوو ➔ هێلێن جودا دبنە ئێک هێلا گرێدای ل دەرڤەیێ شێوەی (شێوە د ناڤ دا)
    if (outline > 0 && state != NodeState.locked) {
      final op = ringPath(sides, c + const Offset(0, lipH / 2), r * 1.24);
      final oc = state == NodeState.gold
          ? const Color(0xFFFFD84D)
          : (boost ? const Color(0xFFFF7A93) : _lighten(color, 0.30));
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = oc.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = oc;
      for (final m in op.computeMetrics()) {
        final part = m.extractPath(0, m.length * outline.clamp(0.0, 1.0));
        canvas.drawPath(part, glow);
        canvas.drawPath(part, line);
      }
    }
    if (state != NodeState.locked && sides < 3 && outline <= 0) {
      // ⭕ بازنە: ئەلقەیەکا ناڤخۆیی (تەمام ➔ سپی)
      canvas.drawCircle(
          c + Offset(0, dy),
          r * 0.80,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = filled > 0 ? Colors.white.withValues(alpha: 0.95) : Colors.black.withValues(alpha: 0.18));
    }
    if (state != NodeState.locked && sides >= 3 && outline <= 0) {
      final inner = polyPoints(sides, c + Offset(0, dy), r * 0.80);
      final on = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = state == NodeState.gold ? const Color(0xFFFFFBEA) : Colors.white;
      final off = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.20);
      // دەستپێک: لایێ سەری، ب ئاراستەیا دەمژمێرێ
      final first = sides.isEven ? sides - 1 : 0;
      for (var k = 0; k < sides; k++) {
        final i = (first + k) % sides;
        final a = inner[i], b = inner[(i + 1) % sides];
        final a2 = Offset.lerp(a, b, 0.16)!, b2 = Offset.lerp(a, b, 0.84)!;
        canvas.drawLine(a2, b2, k < filled ? on : off);
      }
    }

    // ── رۆهناهیا سەری (glossy) ──
    if (state != NodeState.locked) {
      canvas.save();
      canvas.clipPath(face);
      final hl = Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.center, [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0)]);
      canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, rect.right, rect.center.dy), hl);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ShapePainter o) =>
      o.sides != sides ||
      o.filled != filled ||
      o.state != state ||
      o.color != color ||
      o.boost != boost ||
      o.pressed != pressed ||
      o.ring != ring ||
      o.outline != outline ||
      o.t != t ||
      o.current != current;
}

/// ✨ زێڕ: تیشکا رۆهناهیێ + ستێرکێن بچووک — ⚡ بووست: برووسکێن ل دۆر وانەیا نوکە
class FxPainter extends CustomPainter {
  final int sides;
  final bool gold, lightning, pressed;
  final Animation<double> anim;
  FxPainter({required this.sides, required this.gold, required this.lightning, required this.anim, this.pressed = false})
      : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final c0 = Offset(size.width / 2, size.height / 2 - ShapePainter.lipH / 2);
    final (c, r) = _fit(sides, c0, size.width * 0.30);
    final dy = pressed ? ShapePainter.lipH - 2 : 0.0;
    if (gold) {
      // تیشکا رۆهناهیێ (هەر ٢.٤ چرکە)
      final face = polyPath(sides, c + Offset(0, dy), r);
      final k = (t * 1.6).clamp(0.0, 1.0);
      if (k < 1) {
        canvas.save();
        canvas.clipPath(face);
        final x = c.dx - r * 1.6 + k * r * 3.2;
        final band = Paint()
          ..shader = ui.Gradient.linear(Offset(x - r * 0.45, c.dy - r), Offset(x + r * 0.45, c.dy + r), [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0),
          ], const [0.2, 0.5, 0.8]);
        canvas.drawRect(Rect.fromCircle(center: c, radius: r * 1.3), band);
        canvas.restore();
      }
      // ستێرکێن ب چار سەری
      const spots = [Offset(-1.05, -0.85), Offset(1.12, -0.35), Offset(0.85, 0.95), Offset(-1.2, 0.55)];
      for (var i = 0; i < spots.length; i++) {
        final ph = (t + i * 0.27) % 1.0;
        final s = sin(ph * pi);
        if (s <= 0.02) continue;
        _star(canvas, c + spots[i] * r, r * 0.22 * s, Colors.white.withValues(alpha: 0.95 * s));
      }
    }
    if (lightning) {
      final frame = (t * 14).floor();
      final rng = Random(frame * 7919 + sides);
      for (var b = 0; b < 3; b++) {
        if (rng.nextDouble() < 0.25) continue;
        final ang = rng.nextDouble() * 2 * pi;
        final dir = Offset(cos(ang), sin(ang));
        final norm = Offset(-dir.dy, dir.dx);
        final start = c + dir * r * 1.62;
        final pts = <Offset>[start];
        for (var s = 1; s <= 4; s++) {
          pts.add(start + dir * (r * 0.16 * s) + norm * ((rng.nextDouble() - 0.5) * r * 0.32));
        }
        final path = Path()..addPolygon(pts, false);
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = const Color(0xFFFF5A7A).withValues(alpha: 0.45)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..strokeJoin = StrokeJoin.miter
              ..color = const Color(0xFFFFF0F4));
      }
      // پرشنگ
      for (var s = 0; s < 5; s++) {
        final a = rng.nextDouble() * 2 * pi, d = r * (1.5 + rng.nextDouble() * 0.6);
        canvas.drawCircle(c + Offset(cos(a), sin(a)) * d, 1.6 + rng.nextDouble() * 1.6,
            Paint()..color = const Color(0xFFFFC2D0).withValues(alpha: 0.9));
      }
    }
  }

  void _star(Canvas canvas, Offset p, double s, Color col) {
    final path = Path()
      ..moveTo(p.dx, p.dy - s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s)
      ..close();
    canvas.drawPath(path, Paint()..color = col);
  }

  @override
  bool shouldRepaint(FxPainter o) => true;
}

// ═══════════════════════ گرێ (Node) ═══════════════════════
class PathNodeView extends StatefulWidget {
  final int sides, filled;
  final NodeState state;
  final Color color;
  final bool current, boost;
  final double size;
  final IconData icon;
  final VoidCallback? onTap;

  /// ✨ هێلا دەرڤە ب ئەنیمەیشن دهێتە کێشان (جارا ئێکێ پشتی تەمامبوونێ)
  final bool drawIn;
  const PathNodeView({
    super.key,
    required this.sides,
    required this.filled,
    required this.state,
    required this.color,
    this.current = false,
    this.boost = false,
    this.size = 112,
    this.icon = Icons.star_rounded,
    this.onTap,
    this.drawIn = false,
  });

  @override
  State<PathNodeView> createState() => _PathNodeViewState();
}

class _PathNodeViewState extends State<PathNodeView> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  bool _down = false;

  bool get _animated => widget.state == NodeState.gold || widget.current;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PathNodeView old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_animated && _c == null) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    } else if (!_animated && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final s = w.size;
    Widget body(double t) {
      final pulse = w.current ? 1 + 0.035 * sin(t * 2 * pi * 2) : 1.0;
      final iconColor = switch (w.state) {
        NodeState.locked => AppColors.lockIcon,
        _ => Colors.white,
      };
      final (cc, rr) = _fit(w.sides, Offset(s / 2, s / 2 - ShapePainter.lipH / 2), s * 0.30);
      final dy = _down ? ShapePainter.lipH - 2 : 0.0;
      Widget center;
      if (w.state == NodeState.gold) {
        // 🏅 لۆگۆ د ناڤ زێڕی دا هاتییە هەلکۆلین (نە وێنەیەکێ پێڤەکری)
        center = Image.asset('assets/brand/logo_gold.webp', width: rr * (w.sides == 3 ? 1.05 : 1.3), height: rr * (w.sides == 3 ? 1.05 : 1.3));
      } else {
        center = Icon(
          w.state == NodeState.locked ? Icons.lock_rounded : (w.state == NodeState.done ? Icons.check_rounded : w.icon),
          size: rr * 0.95,
          color: iconColor,
          shadows: w.state == NodeState.locked ? null : [Shadow(color: Colors.black.withValues(alpha: 0.25), offset: const Offset(0, 2), blurRadius: 2)],
        );
      }
      return Transform.scale(
        scale: pulse,
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: w.drawIn ? 0 : 1, end: 1),
                duration: Duration(milliseconds: w.drawIn ? 1100 : 1),
                curve: Curves.easeInOutCubic,
                builder: (_, o, __) => CustomPaint(
                  painter: ShapePainter(
                    sides: w.sides,
                    filled: w.filled,
                    state: w.state,
                    color: w.color,
                    boost: w.boost,
                    current: w.current,
                    pressed: _down,
                    ring: w.current && w.sides > 0 ? w.filled / w.sides : -1,
                    outline: (w.state == NodeState.done || w.state == NodeState.gold) ? o : 0,
                  ),
                ),
              ),
            ),
            Positioned(left: cc.dx - rr, top: cc.dy - rr + dy, width: rr * 2, height: rr * 2, child: Center(child: center)),
            if (_c != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: FxPainter(
                      sides: w.sides,
                      gold: w.state == NodeState.gold,
                      lightning: w.boost && w.current,
                      anim: _c!,
                      pressed: _down,
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        w.onTap?.call();
      },
      child: _c == null ? body(0) : AnimatedBuilder(animation: _c!, builder: (_, __) => body(_c!.value)),
    );
  }
}

// ═══════════════════════ دەستپێکرنا کۆرسێ ═══════════════════════
class PathFx {
  static String? justDone; // ✨ هێلا دەرڤە ب ئەنیمەیشن
  static String? pendingGold;
  static String? pendingStage;
  static bool goldFailed = false;
}

void _openLessonSheet(BuildContext context, PathLesson l) {
  final p = ProgressService.instance;
  final n = p.nativeLang;
  final done = p.lessonDone(l), gold = p.lessonGold(l);
  final c = p.coursesDone(l);
  final color = gold ? const Color(0xFFE0A21B) : l.stage.color;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: n.direction,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(
              width: 64,
              height: 64,
              child: PathNodeView(
                sides: l.courses,
                filled: c,
                state: gold ? NodeState.gold : (done ? NodeState.done : NodeState.open),
                color: l.stage.color,
                size: 64,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(n, 'وانە ${kuNum(l.index + 1)} · قۆناغا ${kuNum(l.stage.no)}', 'Lektion ${l.index + 1} · Stufe ${l.stage.no}',
                    'Lesson ${l.index + 1} · Stage ${l.stage.no}'),
                    style: TextStyle(color: AppColors.fg60, fontSize: 13)),
                Text(l.unit.title(n).replaceFirst(RegExp(r'^(قۆناغا [٠-٩]+: |Einheit \d+: |Unit \d+: )'), ''), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  gold
                      ? tr(n, '🏅 زێڕ — دووبارەکرن: XP ١ بۆ هەر بەرسڤەکێ', '🏅 Gold – Wiederholen: 1 XP pro Antwort', '🏅 Gold – replay: 1 XP per answer')
                      : done
                          ? tr(n, '✅ تەمام — دووبارە بکە دا ببیتە زێڕ 🏅', '✅ Fertig – wiederhole für Gold 🏅', '✅ Done – replay for gold 🏅')
                          : tr(n, 'کۆرس ${kuNum(c + 1)} ژ ${kuNum(l.courses)}${isPronounCourse(l, c) ? ' · 👤 جهێناڤ' : ''}',
                              'Kurs ${c + 1} von ${l.courses}${isPronounCourse(l, c) ? ' · 👤 Pronomen' : ''}',
                              'Course ${c + 1} of ${l.courses}${isPronounCourse(l, c) ? ' · 👤 Pronouns' : ''}'),
                  style: TextStyle(color: gold || done ? AppColors.goldText : AppColors.fg70, fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final w in l.concepts.take(5))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(12)),
                child: Text('${w.emoji} ${w.text(p.targetLang)}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13)),
              ),
          ]),
          if (done) ...[
            const SizedBox(height: 10),
            Text(
              tr(n, 'دووبارەکرن: پرسیارێن ب زەحمەتتر و تێکەل ژ هەمی کۆرسێن ڤێ وانێ. بۆ زێڕێ ٧٠٪+ پێدڤییە. XP ١ بۆ هەر بەرسڤەکا دروست.',
                  'Wiederholung: schwierigere, gemischte Fragen. Für Gold brauchst du 70 %+. 1 XP pro richtige Antwort.',
                  'Replay: harder mixed questions. 70%+ for gold. 1 XP per correct answer.'),
              style: TextStyle(color: AppColors.fg60, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              startPathLesson(context, l);
            },
            child: Text(
              done
                  ? (gold ? tr(n, '🔁 دووبارەکرن', '🔁 Wiederholen', '🔁 Replay') : tr(n, '🏅 بۆ زێڕێ', '🏅 Für Gold', '🏅 Go for gold'))
                  : (c == 0 ? tr(n, 'دەستپێبکە', 'Start', 'Start') : tr(n, 'بەردەوام بە', 'Weiter', 'Continue')),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
        ]),
      ),
    ),
  );
}

void startPathLesson(BuildContext context, PathLesson l) {
  final p = ProgressService.instance;
  final n = p.nativeLang;
  if (p.hearts <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(n, 'دلێن تە نەمان 💔 هەر خولەکەکێ دلەک دزڤڕیت', 'Keine Herzen mehr 💔', 'Out of hearts 💔'))));
    return;
  }
  final done = p.lessonDone(l);
  final c = p.coursesDone(l);
  Future<void> after(int pct) async {
    final wasStageDone = p.stageDone(l.stage);
    final wasDone = p.lessonDone(l);
    final gold = await p.pathCourseDone(l, hard: done, percent: pct);
    if ((!wasDone && p.lessonDone(l)) || gold) {
      PathFx.justDone = l.id;
      Future.delayed(const Duration(seconds: 8), () => PathFx.justDone = null);
    }
    if (gold) {
      PathFx.pendingGold = l.id;
    } else if (done && !p.lessonGold(l)) {
      PathFx.goldFailed = true;
    }
    if (!wasStageDone && p.stageDone(l.stage)) PathFx.pendingStage = l.stage.id;
  }

  Widget screen;
  if (l.isAlphabet && !done && c == 0) {
    screen = LetterLessonScreen(unit: l.unit, countUnit: false, onDone: after);
  } else {
    final pron = !done && isPronounCourse(l, c);
    final cs = courseConcepts(l, c, hard: done);
    screen = InteractiveLessonScreen(
      unit: l.unit,
      concepts: pron ? cs.take(3).toList() : cs,
      countUnit: false,
      hard: done,
      redo: done,
      onDone: after,
      // 👤 جهێناڤ د هەمی کۆرسان دا؛ کۆرسا جهێناڤان پتر
      pronounTier: l.isAlphabet ? -1 : pronounTier(max(1, stageNumber(l.stage))),
      pronounCount: pron ? 7 : (done ? 3 : 2),
    );
  }
  void go() => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  final firstOfUnit = pathLessons.firstWhere((x) => x.unit.id == l.unit.id) == l;
  if (!done && c == 0 && firstOfUnit && l.isAlphabet && !p.grammarSeen('${l.unit.id}_letters')) {
    LetterCardsScreen.open(context, l.unit, onStart: go);
  } else if (!done && c == 0 && firstOfUnit && l.unit.grammar != null && !p.grammarSeen(l.unit.id)) {
    showGrammarCard(context, l.unit, onStart: go);
  } else {
    go();
  }
}

// ═══════════════════════ رێک ═══════════════════════
/// هەمی رێک وەکی لیستا ویجێتان (د ناڤ ListView ـا سەرەکی دا)
/// [only] = تنێ ئەڤ بەشە (بۆ بەشێن تەمامکری د پرۆفایلێ دا)؛ null = بەشێ نوکە
List<Widget> buildPathItems(BuildContext context, {required GlobalKey currentKey, List<PathSection>? only}) {
  final p = ProgressService.instance;
  final boost = RewardsService.instance.boostActive && RewardsService.instance.xpMultiplier >= 2;
  final german = p.targetLang == AppLanguage.german;
  final out = <Widget>[];
  if (boost) out.add(const _BoostBanner());
  final finished = only == null ? p.finishedSections : const <PathSection>[];
  if (finished.isNotEmpty) out.add(_FinishedChip(finished));
  for (final sec in only ?? p.visibleSections) {
    out.add(_SectionHeader(sec));
    if (sec.comingSoon) {
      out.add(const _SoonTeaser());
      continue;
    }
    for (var si = 0; si < sec.stages.length; si++) {
      final st = sec.stages[si];
      final lek = st.lektion > 0 ? appLektionen.where((x) => x.n == st.lektion).firstOrNull : null;
      final firstOfLek = si == 0 || sec.stages[si - 1].lektion != st.lektion;
      final lastOfLek = si == sec.stages.length - 1 || sec.stages[si + 1].lektion != st.lektion;
      if (german && lek != null && firstOfLek) out.add(_LektionHeader(lek));
      out.add(_StageHeader(st));
      out.add(_StageGrid(st: st, currentKey: currentKey, boost: boost, lekTest: german && lastOfLek ? lek : null));
      // 🪙 پشتی ئەزموونا وانێ: پرسیارا دیاریێ
      if (german && lek != null && lastOfLek) out.add(ExamCoinNode(examId: 'lek_${lek.n}', section: lek.section));
      out.add(const SizedBox(height: 12));
    }
  }
  // 🔒 بەشێ داهاتی: دیار نابیت هەتا بەشێ نوکە ب دوماهی بهێت — تنێ ئەڤ کارتە
  if (only == null) {
    final a = p.activeSection, nx = p.nextSection;
    if (a != null && nx != null) out.add(_NextSectionCard(a, nx));
  }
  return out;
}

/// ✅ «بەشێن تەمامکری د پرۆفایلێ دا نە»
class _FinishedChip extends StatelessWidget {
  final List<PathSection> secs;
  const _FinishedChip(this.secs);
  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FinishedSectionScreen(secs.last))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            const Text('✅', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(n, '«${secs.last.title(n)}» تەمام بوو 🎉 — نوکە د پرۆفایلا تە دایە', '„${secs.last.title(n)}“ geschafft 🎉 — jetzt in deinem Profil',
                    '“${secs.last.title(n)}” done 🎉 — now in your profile'),
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.fg, fontSize: 14),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.fg54),
          ]),
        ),
      ),
    );
  }
}

/// 🔒 کارتا بەشێ داهاتی ل دوماهیا بەشێ نوکە
class _NextSectionCard extends StatelessWidget {
  final PathSection cur, next;
  const _NextSectionCard(this.cur, this.next);
  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    final total = cur.stages.length;
    final done = cur.stages.where(p.stageDone).length;
    final left = total - done;
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 2),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(switch (cur.n) { 1 => '🌱', 2 => '🌿', _ => '🌳' }, style: const TextStyle(fontSize: 34)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(n.direction == TextDirection.rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, color: AppColors.goldText, size: 28),
          ),
          Stack(alignment: Alignment.bottomRight, children: [
            Opacity(opacity: 0.55, child: Text(switch (next.n) { 2 => '🌿', _ => '🌳' }, style: const TextStyle(fontSize: 34))),
            const Text('🔒', style: TextStyle(fontSize: 16)),
          ]),
        ]),
        const SizedBox(height: 10),
        Text(next.title(n), textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.fg)),
        const SizedBox(height: 6),
        Text(
          next.comingSoon
              ? tr(n, '🔒 زوو دێ ئێت', '🔒 Bald verfügbar', '🔒 Coming soon')
              : tr(
                  n,
                  'دەمێ تو هەمی قۆناغێن «${cur.title(n)}» ب دوماهی بینی، «${next.title(n)}» بۆ تە ڤەدبیت و «${cur.title(n)}» دچیتە د پرۆفایلا تە دا.',
                  'Wenn du alle Stufen von „${cur.title(n)}“ geschafft hast, öffnet sich „${next.title(n)}“ und „${cur.title(n)}“ wandert in dein Profil.',
                  'Finish every stage of “${cur.title(n)}” to open “${next.title(n)}”. “${cur.title(n)}” then moves to your profile.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.fg70, height: 1.6, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 10,
            color: AppColors.gold,
            backgroundColor: AppColors.chip,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          left <= 0
              ? tr(n, 'تەمام! 🎉', 'Geschafft! 🎉', 'Done! 🎉')
              : tr(n, '${kuNum(left)} قۆناغ ماینە', 'Noch $left Stufen', '$left stages to go'),
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.goldText),
        ),
      ]),
    );
  }
}

/// 📚 بەشەکێ تەمامکری (ژ پرۆفایلێ): هەمی وانە بۆ دووبارەکرن و زێڕکرنێ
class FinishedSectionScreen extends StatefulWidget {
  final PathSection sec;
  const FinishedSectionScreen(this.sec, {super.key});
  @override
  State<FinishedSectionScreen> createState() => _FinishedSectionScreenState();
}

class _FinishedSectionScreenState extends State<FinishedSectionScreen> {
  final _key = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    final first = pathSections.where((s) => s.n > 0).firstOrNull;
    final secs = [
      if (widget.sec == first) ...pathSections.where((s) => s.n == 0),
      widget.sec,
    ];
    return Directionality(
      textDirection: n.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.sec.title(n))),
        body: ListenableBuilder(
          listenable: p,
          builder: (ctx, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: buildPathItems(ctx, currentKey: _key, only: secs),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════ قۆناغ: دوو ستوون (وەکی خشتێن دیواری) ═══════════════════════
enum _Kind { lesson, review, exam }

class _Item {
  final _Kind kind;
  final PathLesson? lesson;
  const _Item(this.kind, [this.lesson]);
}

/// پەیڤێن قۆناغێن بەری ڤێ (بۆ بازنێ دووبارەکرنێ)
List<WordConcept> reviewConcepts(PathStage st) {
  final prev = pathStages.where((x) => x.gIndex < st.gIndex && x.section > 0).toList();
  if (prev.isEmpty) return const [];
  final rnd = Random();
  final recent = [for (final x in prev.reversed.take(2)) for (final l in x.lessons) ...l.concepts]..shuffle(rnd);
  final older = [for (final x in prev.reversed.skip(2)) for (final l in x.lessons) ...l.concepts]..shuffle(rnd);
  final out = <WordConcept>[...recent.take(older.isEmpty ? 9 : 6), ...older.take(3)];
  return out..shuffle(rnd);
}

class _StageGrid extends StatelessWidget {
  final PathStage st;
  final GlobalKey currentKey;
  final bool boost;
  final LektionInfo? lekTest;
  const _StageGrid({required this.st, required this.currentKey, required this.boost, this.lekTest});

  List<_Item> _items() {
    final items = [for (final l in st.lessons) _Item(_Kind.lesson, l)];
    // 🔁 بازنا دووبارەکرنێ: د ناڤەراستا قۆناغێ دا (ژ قۆناغا دووێ ڤە)
    if (st.section > 0 && pathStages.any((x) => x.gIndex < st.gIndex && x.section > 0)) {
      items.insert((st.lessons.length / 2).ceil(), const _Item(_Kind.review));
    }
    // 🏁 بازنا ئەزموونێ: دوماهیا قۆناغێ
    if (st.section > 0) items.add(const _Item(_Kind.exam));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    final cur = p.currentLesson;
    final items = _items();
    final unlocked = p.stageUnlocked(st);
    final stageDone = p.stageDone(st);
    final rtl = n.direction == TextDirection.rtl;
    return LayoutBuilder(builder: (ctx, cons) {
      final w = cons.maxWidth;
      final size = min(w * 0.40, 150.0);
      final step = size * 0.66;
      const top = 50.0;
      double cx(int i) => w * ((i.isEven == rtl) ? 0.72 : 0.28);
      double cy(int i) => top + i * step + size / 2 - ShapePainter.lipH / 2;
      final h = top + (items.length - 1) * step + size + 8;
      // چەند ژ سەری تەمام بوون (بۆ رەنگێ هێلێ)
      var doneUpTo = -1;
      for (var i = 0; i < items.length; i++) {
        if (_done(items[i], p)) {
          doneUpTo = i;
        } else {
          break;
        }
      }
      final children = <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _LinkPainter(
              points: [for (var i = 0; i < items.length; i++) Offset(cx(i), cy(i))],
              doneUpTo: doneUpTo,
              color: boost && unlocked ? const Color(0xFFE0405E) : st.color,
              faded: !unlocked,
            ),
          ),
        ),
      ];
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        final left = cx(i) - size / 2, topY = top + i * step;
        Widget node;
        var isCur = false;
        String? bubble;
        switch (it.kind) {
          case _Kind.lesson:
            final l = it.lesson!;
            final lu = p.lessonUnlocked(l);
            final done = p.lessonDone(l);
            final gold = p.lessonGold(l);
            isCur = cur == l;
            if (isCur) bubble = p.coursesDone(l) == 0 ? tr(n, 'دەستپێبکە', 'START', 'START') : '${kuNum(p.coursesDone(l))}/${kuNum(l.courses)}';
            node = PathNodeView(
              sides: l.courses,
              filled: p.coursesDone(l),
              state: gold ? NodeState.gold : (done ? NodeState.done : (lu ? NodeState.open : NodeState.locked)),
              color: st.color,
              current: isCur,
              boost: boost && lu && !gold,
              size: size,
              drawIn: PathFx.justDone == l.id,
              icon: l.isAlphabet ? Icons.abc_rounded : Icons.star_rounded,
              onTap: () => _tapLesson(context, l),
            );
          case _Kind.review:
            final open = unlocked && p.lessonDone(st.lessons[(st.lessons.length / 2).ceil() - 1]);
            final done = p.reviewDone(st);
            node = PathNodeView(
              sides: 0,
              filled: done ? 1 : 0,
              state: done ? NodeState.done : (open ? NodeState.open : NodeState.locked),
              color: _darken(st.color, 0.12),
              size: size * 0.86,
              icon: Icons.replay_rounded,
              onTap: () => open ? _openReview(context, st) : _lockedTip(context, n),
            );
          case _Kind.exam:
            final id = lekTest != null ? 'lek_${lekTest!.n}' : 'st_${st.id}';
            final best = p.examBest(id);
            final state = !stageDone
                ? NodeState.locked
                : (best != null && best >= 90 ? NodeState.gold : (best != null && best >= 60 ? NodeState.done : NodeState.open));
            node = PathNodeView(
              sides: 0,
              filled: best == null ? 0 : 1,
              state: state,
              color: _darken(st.color, 0.22),
              size: size * 0.92,
              icon: Icons.flag_rounded,
              onTap: () => stageDone ? _openExam(context, st, lekTest) : _lockedTip(context, n, exam: true),
            );
            if (best != null) bubble = '$best%';
        }
        final ns = it.kind == _Kind.lesson ? size : size * (it.kind == _Kind.exam ? 0.92 : 0.86);
        children.add(Positioned(
          left: cx(i) - ns / 2,
          top: topY + (size - ns) / 2,
          width: ns,
          height: ns,
          child: isCur ? KeyedSubtree(key: currentKey, child: node) : node,
        ));
        if (bubble != null) {
          children.add(Positioned(
            left: left - 30,
            width: size + 60,
            top: topY - (isCur ? 44 : 30) + (size - ns) / 2,
            child: Center(
              child: isCur
                  ? _StartBubble(color: boost ? _maroon : st.color, label: bubble)
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10)),
                      child: Text(bubble, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.fg70)),
                    ),
            ),
          ));
        }
      }
      return SizedBox(height: h, child: Stack(clipBehavior: Clip.none, children: children));
    });
  }

  bool _done(_Item it, ProgressService p) => switch (it.kind) {
        _Kind.lesson => p.lessonDone(it.lesson!),
        _Kind.review => p.reviewDone(st),
        _Kind.exam => (p.examBest(lekTest != null ? 'lek_${lekTest!.n}' : 'st_${st.id}') ?? 0) >= 60,
      };
}

class _LinkPainter extends CustomPainter {
  final List<Offset> points;
  final int doneUpTo;
  final Color color;
  final bool faded;
  _LinkPainter({required this.points, required this.doneUpTo, required this.color, required this.faded});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    Path seg(int a, int b) {
      final path = Path()..moveTo(points[a].dx, points[a].dy);
      for (var i = a + 1; i <= b; i++) {
        final p0 = points[i - 1], p1 = points[i];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        path.quadraticBezierTo(p0.dx, mid.dy, mid.dx, mid.dy);
        path.quadraticBezierTo(p1.dx, mid.dy, p1.dx, p1.dy);
      }
      return path;
    }

    final rest = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = (AppColors.dark ? Colors.white : Colors.black).withValues(alpha: faded ? 0.06 : 0.10);
    canvas.drawPath(seg(0, points.length - 1), rest);
    if (doneUpTo >= 1) {
      final on = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.85);
      canvas.drawPath(seg(0, min(doneUpTo + 1, points.length - 1)), on);
    }
  }

  @override
  bool shouldRepaint(_LinkPainter o) => o.doneUpTo != doneUpTo || o.color != color || o.faded != faded || o.points.length != points.length;
}

void _lockedTip(BuildContext context, AppLanguage n, {bool exam = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(exam
          ? tr(n, 'پێشی هەمی وانەیێن ڤێ قۆناغێ تەمام بکە، پاشان ئەزموون ڤەدبیت 🔒', 'Erst alle Lektionen dieser Stufe 🔒',
              'Finish all lessons of this stage first 🔒')
          : tr(n, 'پێشی وانەیێن بەری ڤێ تەمام بکە 🔒', 'Erst die Lektionen davor 🔒', 'Finish the lessons before first 🔒'))));
}

/// 🔁 دووبارەکرنا قۆناغێن بەری
void _openReview(BuildContext context, PathStage st) {
  final p = ProgressService.instance;
  final cs = reviewConcepts(st);
  if (cs.isEmpty || p.hearts <= 0) {
    if (p.hearts <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(p.nativeLang, 'دلێن تە نەمان 💔', 'Keine Herzen 💔', 'Out of hearts 💔'))));
    }
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => InteractiveLessonScreen(
        unit: null,
        concepts: cs,
        countUnit: false,
        redo: p.reviewDone(st),
        onDone: (_) => p.markReview(st),
        pronounTier: pronounTier(max(1, stageNumber(st))),
        pronounCount: 3,
      ),
    ),
  );
}

/// 🏁 ئەزموونا قۆناغێ (یان ئەزموونا وانێ ل دوماهیا وانەکا پەرتووکێ)
void _openExam(BuildContext context, PathStage st, LektionInfo? lek) {
  final p = ProgressService.instance;
  if (lek != null) {
    openLektionTest(context, lek);
    return;
  }
  if (p.hearts <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(p.nativeLang, 'دلێن تە نەمان 💔', 'Keine Herzen 💔', 'Out of hearts 💔'))));
    return;
  }
  final all = [for (final l in st.lessons) ...l.concepts]..shuffle();
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => InteractiveLessonScreen(
        unit: st.lessons.first.unit,
        concepts: all.take(8).toList(),
        countUnit: false,
        hard: true,
        redo: p.examBest('st_${st.id}') != null,
        onDone: (pct) => p.saveExam('st_${st.id}', pct),
        pronounTier: pronounTier(max(1, stageNumber(st))),
        pronounCount: 3,
      ),
    ),
  );
}

void _tapLesson(BuildContext context, PathLesson l) {
  final p = ProgressService.instance;
  final n = p.nativeLang;
  final st = l.stage;
  if (!p.stageUnlocked(st)) {
    final open = p.openStageExcept(st);
    if (open != null) {
      final left = open.lessons.where((x) => !p.lessonDone(x)).length;
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: n.direction,
          child: AlertDialog(
            title: Text(tr(n, '🔒 پێشی قۆناغا خۆ تەمام بکە', '🔒 Erst die aktuelle Stufe beenden', '🔒 Finish your stage first')),
            content: Text(tr(
                n,
                'تە دەست ب قۆناغا ${kuNum(open.no)} (${_secName(open.section, n)}) کرییە. ${kuNum(left)} وانە ماینە — پشتی تەمامکرنا وێ تو دشێی بازدەیە هەر قۆناغەکا تە بڤێت.',
                'Du hast Stufe ${open.no} begonnen. Noch $left Lektion(en) – danach kannst du springen, wohin du willst.',
                'You started stage ${open.no}. $left lesson(s) left – then you can jump anywhere.')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: n.direction,
        child: AlertDialog(
          title: Text(tr(n, '⤴️ بازدان بۆ قۆناغا ${kuNum(st.no)}؟', '⤴️ Zu Stufe ${st.no} springen?', '⤴️ Jump to stage ${st.no}?')),
          content: Text(tr(
              n,
              'ئەگەر تو ڤان بابەتان دزانی، دشێی ژ ڤێرێ دەست پێبکەی. بەلێ تێبینی: پشتی دەستپێکرنێ، دڤێت هەمی وانەیێن ڤێ قۆناغێ تەمام بکەی (هەتا ئەگەر ئێک ژی مابیت).',
              'Wenn du das schon kannst, starte hier. Aber: Einmal begonnen, musst du alle Lektionen dieser Stufe abschließen.',
              'If you already know this, start here. Once started, you must finish all lessons of this stage.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(n, 'نە', 'Nein', 'No'))),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await p.jumpTo(st);
                if (context.mounted) _openLessonSheet(context, st.lessons.first);
              },
              child: Text(tr(n, 'بەلێ، بازدە', 'Ja, springen', 'Yes, jump')),
            ),
          ],
        ),
      ),
    );
    return;
  }
  if (!p.lessonUnlocked(l)) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(n, 'پێشی وانەیا بەری ڤێ تەمام بکە 🔒', 'Schließe zuerst die vorherige Lektion ab 🔒', 'Finish the previous lesson first 🔒'))));
    return;
  }
  _openLessonSheet(context, l);
}

String _secName(int s, AppLanguage n) => tr(n, 'بەشا ${kuNum(s)}', 'Teil $s', 'Section $s');

class _StartBubble extends StatefulWidget {
  final Color color;
  final String label;
  const _StartBubble({required this.color, required this.label});
  @override
  State<_StartBubble> createState() => _StartBubbleState();
}

class _StartBubbleState extends State<_StartBubble> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, child) => Transform.translate(offset: Offset(0, -4 * Curves.easeInOut.transform(c.value)), child: child),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.dark ? AppColors.chip : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fg12, width: 2),
          ),
          child: Text(widget.label, style: TextStyle(color: widget.color, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
        CustomPaint(size: const Size(14, 7), painter: _Tri(AppColors.dark ? AppColors.chip : Colors.white)),
      ]),
    );
  }
}

class _Tri extends CustomPainter {
  final Color c;
  _Tri(this.c);
  @override
  void paint(Canvas canvas, Size s) =>
      canvas.drawPath(Path()..addPolygon([Offset.zero, Offset(s.width, 0), Offset(s.width / 2, s.height)], true), Paint()..color = c);
  @override
  bool shouldRepaint(_Tri o) => o.c != c;
}

class _SectionHeader extends StatelessWidget {
  final PathSection sec;
  const _SectionHeader(this.sec);
  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    final total = sec.stages.length;
    final done = sec.stages.where(p.stageDone).length;
    final gold = total > 0 && sec.stages.every(p.stageGold);
    final colors = switch (sec.n) {
      0 => const [Color(0xFF2E7DB5), Color(0xFF1F5A86)],
      1 => const [Color(0xFF3F9A4B), Color(0xFF256B33)],
      2 => const [Color(0xFF3E6FC2), Color(0xFF2A4B8D)],
      _ => const [Color(0xFF8A4FB8), Color(0xFF5E2F86)],
    };
    return Container(
      margin: const EdgeInsets.only(top: 18, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gold ? const [Color(0xFFE9B23A), Color(0xFFB07A10)] : (sec.comingSoon ? [Colors.blueGrey.shade700, Colors.blueGrey.shade900] : colors)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${sec.title(n)}${gold ? '  👑' : ''}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (sec.comingSoon)
              Text(tr(n, '🔒 زوو دێ ئێت', '🔒 Bald verfügbar', '🔒 Coming soon'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 8,
                  color: const Color(0xFFFFD54F),
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 4),
              Text(tr(n, '${kuNum(done)} / ${kuNum(total)} قۆناغ', '$done / $total Stufen', '$done / $total stages'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Text(switch (sec.n) { 0 => '🔤', 1 => '🌱', 2 => '🌿', _ => '🌳' }, style: const TextStyle(fontSize: 40)),
      ]),
    );
  }
}

class _SoonTeaser extends StatelessWidget {
  const _SoonTeaser();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Opacity(
        opacity: 0.55,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final k in [3, 4, 5, 6])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: IgnorePointer(child: PathNodeView(sides: k, filled: 0, state: NodeState.locked, color: Colors.grey, size: 64)),
            ),
        ]),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  final PathStage st;
  const _StageHeader(this.st);
  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    final gold = p.stageGold(st);
    final unlocked = p.stageUnlocked(st);
    final done = p.stageDone(st);
    final g = st.grammarUnit;
    return Opacity(
      opacity: unlocked ? 1 : 0.62,
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gold ? const [Color(0xFFF2C14E), Color(0xFFC48A12)] : [st.color, _darken(st.color, 0.18)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border(bottom: BorderSide(color: gold ? _goldLip : _darken(st.color, 0.35), width: 4)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                st.section == 0
                    ? tr(n, 'ئەلفوبێ · ${kuNum(st.no)}', 'Alphabet · ${st.no}', 'Alphabet · ${st.no}')
                    : '${_secName(st.section, n)} · ${tr(n, 'قۆناغا ${kuNum(st.no)}', 'Stufe ${st.no}', 'Stage ${st.no}')}${gold ? '  🏅' : (done ? '  ✅' : '')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(st.title(n), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              if (n != p.targetLang)
                Text(st.title(p.targetLang),
                    textDirection: p.targetLang.direction, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          if (!unlocked && st.section > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
              child: Text(tr(n, '⤴️ بازدان', '⤴️ Springen', '⤴️ Jump'), style: const TextStyle(color: Colors.white, fontSize: 12)),
            )
          else if (g != null)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showGrammarCard(context, g),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: const Text('📘', style: TextStyle(fontSize: 18)),
              ),
            )
          else if (st.lessons.first.isAlphabet)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => LetterCardsScreen.open(context, st.lessons.first.unit),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: const Text('🔤', style: TextStyle(fontSize: 18)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _LektionHeader extends StatelessWidget {
  final LektionInfo lek;
  const _LektionHeader(this.lek);
  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
    final title = switch (n) { AppLanguage.badini => lek.titleKu, AppLanguage.german => lek.titleDe, AppLanguage.english => lek.titleEn };
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.fg12, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('📖', style: TextStyle(fontSize: 18, color: lek.color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: TextStyle(fontFamily: 'Sarchia', fontSize: 16, color: AppColors.fg, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.fg, side: BorderSide(color: AppColors.fg24)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DialogScreen(lektion: lek))),
              icon: const Text('💬'),
              label: Text(tr(n, 'دیالۆگ', 'Dialog', 'Dialogue')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.fg, side: BorderSide(color: AppColors.fg24)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GrammarLektionScreen(n: lek.n))),
              icon: const Text('📘'),
              label: Text(tr(n, 'رێزمان', 'Grammatik', 'Grammar')),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// ⚡ بووست چالاکە ➔ بانەرا سۆرێ مەیی ب دەمژمێرێ
class _BoostBanner extends StatefulWidget {
  const _BoostBanner();
  @override
  State<_BoostBanner> createState() => _BoostBannerState();
}

class _BoostBannerState extends State<_BoostBanner> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = RewardsService.instance;
    final n = ProgressService.instance.nativeLang;
    final left = r.boostLeft;
    return Container(
      margin: const EdgeInsets.only(bottom: 6, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB3263E), Color(0xFF5A0F1C)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFFE0405E).withValues(alpha: 0.45), blurRadius: 14)],
      ),
      child: Row(children: [
        const Text('⚡', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(tr(n, 'XP ×${kuNum(r.xpMultiplier)} چالاکە!', 'XP ×${r.xpMultiplier} aktiv!', 'XP ×${r.xpMultiplier} active!'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        Text('${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
            textDirection: TextDirection.ltr, style: const TextStyle(color: Color(0xFFFFD1DC), fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ═══════════════════════ ئاهەنگ: زێڕ / قۆناغ تەمام ═══════════════════════
Future<void> maybeCelebratePath(BuildContext context) async {
  final p = ProgressService.instance;
  final n = p.nativeLang;
  if (PathFx.goldFailed) {
    PathFx.goldFailed = false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(n, 'بۆ زێڕێ ٧٠٪+ پێدڤییە — جارەکا دی تاقی بکە 💪', 'Für Gold brauchst du 70 %+ – nochmal! 💪', 'You need 70%+ for gold – try again! 💪'))));
  }
  final gid = PathFx.pendingGold;
  final sid = PathFx.pendingStage;
  PathFx.pendingGold = null;
  PathFx.pendingStage = null;
  final l = gid == null ? null : pathLessonById(gid);
  final st = sid == null ? null : pathStages.where((s) => s.id == sid).firstOrNull;
  if (l == null && st == null) return;
  final stageGold = st != null && p.stageGold(st);
  await showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: n.direction,
      child: Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 130,
              height: 130,
              child: IgnorePointer(
                child: PathNodeView(
                  sides: (l ?? st!.lessons.first).courses,
                  filled: (l ?? st!.lessons.first).courses,
                  state: l != null || stageGold ? NodeState.gold : NodeState.done,
                  color: (l?.stage ?? st!).color,
                  size: 130,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l != null
                  ? tr(n, '🏅 بوو زێڕ!', '🏅 Gold!', '🏅 Gold!')
                  : (stageGold ? tr(n, '👑 قۆناغا زێڕین!', '👑 Goldene Stufe!', '👑 Golden stage!') : tr(n, '🎉 قۆناغ تەمام بوو!', '🎉 Stufe geschafft!', '🎉 Stage complete!')),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              l != null
                  ? tr(n, 'تە ئەڤ وانە ب پرسیارێن ب زەحمەت تەمام کر. هەمی وانەیێن قۆناغێ زێڕ بکە دا قۆناغ ببیتە زێڕ 👑',
                      'Alle Lektionen in Gold = goldene Stufe 👑', 'Make every lesson gold for a golden stage 👑')
                  : tr(n, 'تو دشێی وانەیان دووبارە بکەی دا ببنە زێڕ 🏅', 'Wiederhole Lektionen für Gold 🏅', 'Replay lessons to make them gold 🏅'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.fg70),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(n, 'باشە', 'Weiter', 'Continue'))),
          ]),
        ),
      ),
    ),
  );
}
