import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui.dart';
import 'mascot.dart';

/// 🏆 هونەرێ لیگێ ب کۆدی (بێ وێنە): مەدال · نیشانێن باژێران · سەکۆ · چوارچووڤە
/// هەمی ب ڕەنگێن گرادیێنت، ڕۆناهی و درەوشانا ب لڤین — پاقژ و ب ئێک شێوە.

enum MedalKind { gold, silver, bronze }

const _medalColors = {
  MedalKind.gold: [Color(0xFFFFF3B0), Color(0xFFFFC928), Color(0xFFE09A00), Color(0xFF9C6400)],
  MedalKind.silver: [Color(0xFFFFFFFF), Color(0xFFDCE3EA), Color(0xFFA9B4BF), Color(0xFF6E7B88)],
  MedalKind.bronze: [Color(0xFFFFE0C2), Color(0xFFE59A5C), Color(0xFFB8682E), Color(0xFF7A3F14)],
};
const _ribbon = {
  MedalKind.gold: [Color(0xFFE53935), Color(0xFFFFC107)],
  MedalKind.silver: [Color(0xFF1E88E5), Color(0xFFFFFFFF)],
  MedalKind.bronze: [Color(0xFFEF6C00), Color(0xFF6D4C41)],
};

/// 🥇 مەدال ب پەتک و ستێرک + درەوشانا ب لڤین
class Medal extends StatefulWidget {
  final MedalKind kind;
  final double size;
  final bool shine;
  const Medal({super.key, this.kind = MedalKind.gold, this.size = 120, this.shine = true});

  @override
  State<Medal> createState() => _MedalState();
}

class _MedalState extends State<Medal> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.shine) c.repeat();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size * 1.35,
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => CustomPaint(painter: _MedalPainter(widget.kind, c.value)),
        ),
      );
}

class _MedalPainter extends CustomPainter {
  final MedalKind kind;
  final double t;
  _MedalPainter(this.kind, this.t);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final cols = _medalColors[kind]!;
    final rib = _ribbon[kind]!;
    final r = w * 0.42;
    final center = Offset(w / 2, s.height - r - w * 0.04);

    // 🎗️ پەتک (دوو لا، ب سێبەر)
    for (final side in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(w / 2 + side * w * 0.36, 0)
        ..lineTo(w / 2 + side * w * 0.14, 0)
        ..lineTo(w / 2 - side * w * 0.10, center.dy - r * 0.55)
        ..lineTo(w / 2 + side * w * 0.12, center.dy - r * 0.55)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(colors: side < 0 ? rib : rib.reversed.toList(), stops: const [0.5, 0.5])
                .createShader(Rect.fromLTWH(0, 0, w, center.dy)));
      canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: side < 0 ? 0.0 : 0.18));
    }

    // 🌑 سێبەر
    canvas.drawCircle(center + Offset(0, r * 0.08), r, Paint()..color = Colors.black.withValues(alpha: 0.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // ⭕ لێڤار
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = SweepGradient(colors: [cols[1], cols[3], cols[1], cols[0], cols[1]], transform: GradientRotation(t * 2 * pi))
              .createShader(Rect.fromCircle(center: center, radius: r)));
    // 🟡 ناڤەڕاست
    final ir = r * 0.80;
    canvas.drawCircle(
        center,
        ir,
        Paint()
          ..shader = RadialGradient(colors: [cols[0], cols[1], cols[2]], stops: const [0, 0.55, 1], center: const Alignment(-0.35, -0.4))
              .createShader(Rect.fromCircle(center: center, radius: ir)));
    canvas.drawCircle(center, ir, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.04..color = cols[3].withValues(alpha: 0.6));

    // ⭐ ستێرک (ب دوو ڕەنگان دا وەکی بلند دیار ببیت)
    final star = _star(center, ir * 0.62, ir * 0.27);
    canvas.drawPath(star.shift(Offset(r * 0.03, r * 0.04)), Paint()..color = cols[3].withValues(alpha: 0.55));
    canvas.drawPath(
        star,
        Paint()
          ..shader = LinearGradient(colors: [cols[0], cols[1], cols[2]], begin: Alignment.topLeft, end: Alignment.bottomRight)
              .createShader(Rect.fromCircle(center: center, radius: ir)));

    // ✨ درەوشان: خەتەکا ڕۆهن دبوریت
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
    final x = -r * 1.5 + (r * 4) * ((t * 1.4) % 1.4);
    canvas.translate(center.dx + x - r, 0);
    canvas.rotate(0.45);
    canvas.drawRect(
        Rect.fromLTWH(0, -r * 2, r * 0.32, r * 6),
        Paint()
          ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0)])
              .createShader(Rect.fromLTWH(0, 0, r * 0.32, 10)));
    canvas.restore();
  }

  Path _star(Offset c, double ro, double ri) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? ro : ri;
      final o = c + Offset(cos(a) * rr, sin(a) * rr);
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_MedalPainter o) => o.t != t || o.kind != kind;
}

/// 🏙️ ئاستێن لیگێ: ڕێکا ئەلمانیا (دهۆک ➔ بەرلین)
class LeagueLevel {
  final String ku, de, icon;
  final List<Color> colors;
  const LeagueLevel(this.ku, this.de, this.icon, this.colors);
}

const leagueLevels = <LeagueLevel>[
  LeagueLevel('دهۆک', 'Duhok', '🏔️', [Color(0xFF64B5F6), Color(0xFF1565C0)]),
  LeagueLevel('هەولێر', 'Erbil', '🏰', [Color(0xFF4DD0E1), Color(0xFF00838F)]),
  LeagueLevel('ئەستەنبوڵ', 'Istanbul', '🌉', [Color(0xFFFF8A80), Color(0xFFC62828)]),
  LeagueLevel('ڤیەنا', 'Wien', '🎡', [Color(0xFFCE93D8), Color(0xFF6A1B9A)]),
  LeagueLevel('میونشن', 'München', '⛪', [Color(0xFFE0E0E0), Color(0xFF616161)]),
  LeagueLevel('بەرلین', 'Berlin', '🏛️', [Color(0xFFFFE082), Color(0xFFFF8F00)]),
];

/// 🛡️ نیشانا ئاستێ لیگێ (شێوێ شیلدێ + تیشک + درەوشان)
class LeagueBadge extends StatefulWidget {
  final int level;
  final double size;
  final bool locked;
  const LeagueBadge({super.key, required this.level, this.size = 96, this.locked = false});

  @override
  State<LeagueBadge> createState() => _LeagueBadgeState();
}

class _LeagueBadgeState extends State<LeagueBadge> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = leagueLevels[widget.level.clamp(0, leagueLevels.length - 1)];
    final s = widget.size;
    final top = widget.level == leagueLevels.length - 1;
    return Opacity(
      opacity: widget.locked ? 0.35 : 1,
      child: SizedBox(
        width: s,
        height: s * 1.12,
        child: Stack(alignment: Alignment.center, children: [
          if (top && !widget.locked)
            AnimatedBuilder(
              animation: c,
              builder: (_, __) => Transform.rotate(
                angle: c.value * 2 * pi,
                child: CustomPaint(size: Size(s * 1.1, s * 1.1), painter: _RaysPainter(l.colors[0])),
              ),
            ),
          CustomPaint(size: Size(s * 0.86, s), painter: _ShieldPainter(widget.locked ? const [Color(0xFF8A939B), Color(0xFF4E565C)] : l.colors)),
          Padding(
            padding: EdgeInsets.only(bottom: s * 0.06),
            child: Text(widget.locked ? '🔒' : l.icon, style: TextStyle(fontSize: s * 0.36)),
          ),
        ]),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final List<Color> colors;
  _ShieldPainter(this.colors);

  Path _shield(Size s, double inset) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w / 2, inset)
      ..quadraticBezierTo(w * 0.78, h * 0.10 + inset, w - inset, h * 0.12 + inset)
      ..lineTo(w - inset, h * 0.52)
      ..quadraticBezierTo(w - inset, h * 0.82, w / 2, h - inset)
      ..quadraticBezierTo(inset, h * 0.82, inset, h * 0.52)
      ..lineTo(inset, h * 0.12 + inset)
      ..quadraticBezierTo(w * 0.22, h * 0.10 + inset, w / 2, inset)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size s) {
    final outer = _shield(s, 0);
    canvas.drawPath(outer.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(
        outer,
        Paint()
          ..shader = LinearGradient(colors: [Colors.white, colors[0], colors[1]], stops: const [0, 0.35, 1], begin: Alignment.topLeft, end: Alignment.bottomRight)
              .createShader(Offset.zero & s));
    final inner = _shield(s, s.width * 0.09);
    canvas.drawPath(
        inner,
        Paint()
          ..shader = RadialGradient(colors: [colors[0], colors[1]], center: const Alignment(-0.3, -0.5), radius: 1.0).createShader(Offset.zero & s));
    // ڕۆناهیا سەری
    canvas.save();
    canvas.clipPath(inner);
    canvas.drawOval(Rect.fromLTWH(-s.width * 0.2, -s.height * 0.35, s.width * 1.1, s.height * 0.7),
        Paint()..color = Colors.white.withValues(alpha: 0.18));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShieldPainter o) => o.colors != colors;
}

class _RaysPainter extends CustomPainter {
  final Color color;
  _RaysPainter(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    final p = Paint()..color = color.withValues(alpha: 0.35);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a - 0.12) * r, c.dy + sin(a - 0.12) * r)
        ..lineTo(c.dx + cos(a + 0.12) * r, c.dy + sin(a + 0.12) * r)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter o) => false;
}

/// 🖼️ چوارچووڤێ وێنەیێ پرۆفایلێ (ب ڕەنگێ ئاستی + درەوشانا زڤڕۆک)
class AvatarFrame extends StatefulWidget {
  final int level;
  final double size;
  final Widget child;
  const AvatarFrame({super.key, required this.level, required this.child, this.size = 72});

  @override
  State<AvatarFrame> createState() => _AvatarFrameState();
}

class _AvatarFrameState extends State<AvatarFrame> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = leagueLevels[widget.level.clamp(0, leagueLevels.length - 1)];
    final s = widget.size;
    return AnimatedBuilder(
      animation: c,
      builder: (_, child) => Container(
        width: s,
        height: s,
        padding: EdgeInsets.all(s * 0.06),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [l.colors[1], l.colors[0], Colors.white, l.colors[0], l.colors[1]], transform: GradientRotation(c.value * 2 * pi)),
          boxShadow: [BoxShadow(color: l.colors[0].withValues(alpha: 0.5), blurRadius: s * 0.15)],
        ),
        child: child,
      ),
      child: ClipOval(child: Container(color: AppColors.card, child: widget.child)),
    );
  }
}

/// 🥇🥈🥉 سەکۆ: ٣ کاراکتەر ل سەر ستوینێن زێڕ/زیڤ/برۆنز
class Podium extends StatelessWidget {
  final List<MascotChar> chars; // [1, 2, 3]
  final List<String> names;
  final double width;
  const Podium({super.key, required this.chars, required this.names, this.width = 340});

  @override
  Widget build(BuildContext context) {
    final w = width / 3;
    Widget col(int place, double h, MedalKind kind) {
      final cols = _medalColors[kind]!;
      return SizedBox(
        width: w,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Image(image: chars[place].img(place == 0 ? 'happy_full' : 'full'), height: w * 1.25, fit: BoxFit.contain),
          Text(names[place], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Container(
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              gradient: LinearGradient(colors: [cols[0], cols[1], cols[2]], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: cols[2].withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: Text('${place + 1}', style: TextStyle(fontSize: w * 0.32, fontWeight: FontWeight.w900, color: cols[3])),
          ),
        ]),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
        col(1, w * 0.75, MedalKind.silver),
        col(0, w * 1.05, MedalKind.gold),
        col(2, w * 0.55, MedalKind.bronze),
      ]),
    );
  }
}
