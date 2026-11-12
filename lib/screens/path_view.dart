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
        ..color = AppColors.dark ? const Color(0xFF37464F) : const Color(0xFFE2E6E8);
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
        lipC = AppColors.dark ? const Color(0xFF26333A) : const Color(0xFFC9CED1);
        faceP = Paint()..color = AppColors.dark ? const Color(0xFF37464F) : const Color(0xFFE5E8EA);
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
    if (state != NodeState.locked) {
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
        NodeState.locked => AppColors.dark ? const Color(0xFF52656D) : const Color(0xFFAFB6BA),
        _ => Colors.white,
      };
      final (cc, rr) = _fit(w.sides, Offset(s / 2, s / 2 - ShapePainter.lipH / 2), s * 0.30);
      final dy = _down ? ShapePainter.lipH - 2 : 0.0;
      Widget center;
      if (w.state == NodeState.gold) {
        center = Container(
          width: rr * 1.05,
          height: rr * 1.05,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0xFF7A4E00).withValues(alpha: 0.55), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: ClipOval(child: Image.asset('assets/brand/logo.png', fit: BoxFit.cover)),
        );
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
              child: CustomPaint(
                painter: ShapePainter(
                  sides: w.sides,
                  filled: w.filled,
                  state: w.state,
                  color: w.color,
                  boost: w.boost,
                  current: w.current,
                  pressed: _down,
                  ring: w.current ? w.filled / w.sides : -1,
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
                          : tr(n, 'کۆرس ${kuNum(c + 1)} ژ ${kuNum(l.courses)}', 'Kurs ${c + 1} von ${l.courses}', 'Course ${c + 1} of ${l.courses}'),
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
    final gold = await p.pathCourseDone(l, hard: done, percent: pct);
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
    screen = InteractiveLessonScreen(
      unit: l.unit,
      concepts: courseConcepts(l, c, hard: done),
      countUnit: false,
      hard: done,
      redo: done,
      onDone: after,
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
List<Widget> buildPathItems(BuildContext context, {required GlobalKey currentKey}) {
  final p = ProgressService.instance;
  final n = p.nativeLang;
  final boost = RewardsService.instance.boostActive && RewardsService.instance.xpMultiplier >= 2;
  final cur = p.currentLesson;
  final german = p.targetLang == AppLanguage.german;
  final out = <Widget>[];
  if (boost) out.add(const _BoostBanner());
  var zig = 0;
  for (final sec in pathSections) {
    out.add(_SectionHeader(sec));
    if (sec.comingSoon) {
      out.add(const _SoonTeaser());
      continue;
    }
    for (var si = 0; si < sec.stages.length; si++) {
      final st = sec.stages[si];
      final lek = st.lektion > 0 ? appLektionen.where((x) => x.n == st.lektion).firstOrNull : null;
      final firstOfLek = si == 0 || sec.stages[si - 1].lektion != st.lektion;
      if (german && lek != null && firstOfLek) out.add(_LektionHeader(lek));
      out.add(_StageHeader(st));
      for (final l in st.lessons) {
        final unlocked = p.lessonUnlocked(l);
        final done = p.lessonDone(l);
        final gold = p.lessonGold(l);
        final isCur = cur == l;
        final state = gold ? NodeState.gold : (done ? NodeState.done : (unlocked ? NodeState.open : NodeState.locked));
        const offs = [0.0, 0.55, 0.9, 0.55, 0.0, -0.55, -0.9, -0.55];
        final dx = offs[zig++ % offs.length];
        out.add(Padding(
          key: isCur ? currentKey : null,
          padding: EdgeInsets.only(top: isCur ? 46 : 6, bottom: 14),
          child: LayoutBuilder(builder: (ctx, cons) {
            final span = min(cons.maxWidth * 0.30, 110.0);
            return Transform.translate(
              offset: Offset(dx * span * (n.direction == TextDirection.rtl ? -1 : 1), 0),
              child: Center(
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                  PathNodeView(
                    sides: l.courses,
                    filled: p.coursesDone(l),
                    state: state,
                    color: st.color,
                    current: isCur,
                    boost: boost && unlocked && !gold,
                    icon: l.isAlphabet ? Icons.abc_rounded : (l.index == st.lessons.length - 1 ? Icons.emoji_events_rounded : Icons.star_rounded),
                    onTap: () => _tapLesson(context, l),
                  ),
                  if (isCur) Positioned(top: -44, child: _StartBubble(color: boost ? _maroon : st.color, label: p.coursesDone(l) == 0 ? tr(n, 'دەستپێبکە', 'START', 'START') : '${kuNum(p.coursesDone(l))}/${kuNum(l.courses)}')),
                ]),
              ),
            );
          }),
        ));
      }
      // 📝 ئەزموونا Lektionێ: پشتی دوماهیک قۆناغا وێ
      final lastOfLek = si == sec.stages.length - 1 || sec.stages[si + 1].lektion != st.lektion;
      if (german && lek != null && lastOfLek) {
        out.add(_LektionTest(lek));
        out.add(ExamCoinNode(examId: 'lek_${lek.n}', section: lek.section));
      }
      out.add(const SizedBox(height: 10));
    }
  }
  return out;
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
            color: AppColors.dark ? const Color(0xFF253740) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fg12, width: 2),
          ),
          child: Text(widget.label, style: TextStyle(color: widget.color, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
        CustomPaint(size: const Size(14, 7), painter: _Tri(AppColors.dark ? const Color(0xFF253740) : Colors.white)),
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
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                child: Text(sec.level, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              if (gold) const Text('  👑', style: TextStyle(fontSize: 16)),
            ]),
            const SizedBox(height: 6),
            Text(sec.title(n), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
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
    final a2 = lek.n > 14;
    final title = lek.section - 1 < appSections.length ? appSections[lek.section - 1].title(n) : lek.titleKu;
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: lek.color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
            child: Text(a2 ? 'A2 · L${lek.n - 14}' : (lek.n <= 7 ? 'A1.1 · L${lek.n}' : 'A1.2 · L${lek.n}'),
                textDirection: TextDirection.ltr, style: TextStyle(color: lek.color, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
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

class _LektionTest extends StatelessWidget {
  final LektionInfo lek;
  const _LektionTest(this.lek);
  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    final best = p.examBest('lek_${lek.n}');
    final stages = pathStages.where((s) => s.lektion == lek.n);
    final ready = stages.isNotEmpty && stages.every(p.stageDone);
    final passed = best != null && best >= 60;
    final label = lek.n > 14 ? 'A2 · L${lek.n - 14}' : 'L${lek.n}';
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (!ready) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(tr(n, 'پێشی قۆناغێن ڤێ وانێ تەمام بکە، پاشان ئەزموون ڤەدبیت 🔒', 'Schließe zuerst die Stufen ab 🔒',
                    'Finish the stages first 🔒'))));
            return;
          }
          openLektionTest(context, lek);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: ready
                ? LinearGradient(colors: passed ? const [Color(0xFF58CC02), Color(0xFF2E9E00)] : [lek.color, _darken(lek.color, 0.2)])
                : null,
            color: ready ? null : AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ready ? Colors.transparent : AppColors.fg12, width: 1.5),
          ),
          child: Row(children: [
            Text(passed ? '🏆' : (ready ? '📝' : '🔒'), style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(n, 'ئەزموونا وانێ · $label', 'Test · $label', 'Test · $label'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ready ? Colors.white : AppColors.fg)),
                Text(
                  best != null
                      ? '${tr(n, 'باشترین ئەنجام', 'Bestes Ergebnis', 'Best')}: $best%'
                      : (ready
                          ? tr(n, 'ئەگەر تە بڤێت خۆ تاقی بکە ✨', 'Teste dich, wenn du willst ✨', 'Test yourself if you like ✨')
                          : tr(n, 'پشتی تەمامکرنا قۆناغێن سەری ڤەدبیت', 'Nach den Stufen oben', 'Unlocks after the stages above')),
                  style: TextStyle(fontSize: 12, color: ready ? Colors.white70 : AppColors.fg60),
                ),
              ]),
            ),
            if (ready) const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32),
          ]),
        ),
      ),
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
