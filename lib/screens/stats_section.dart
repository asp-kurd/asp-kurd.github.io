import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/progress_service.dart';
import '../ui.dart';

/// 📊 ئامار: دارا تە، دەمێ خواندنێ، رۆژێن ڤێبوونێ و کارت
class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TreeCard(xp: p.xp, lang: p.nativeLang),
        const SizedBox(height: 14),
        StudyChart(p: p),
        const SizedBox(height: 14),
        PracticeHeatmap(p: p),
        const SizedBox(height: 14),
        StatTiles(p: p),
      ]),
    );
  }
}

BoxDecoration _cardBox() => BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    );

// ───────── 🌳 دارا تە ─────────
class TreeStage {
  final int xp;
  final String emoji, ku, de, en;
  const TreeStage(this.xp, this.emoji, this.ku, this.de, this.en);
}

const treeStages = [
  TreeStage(0, '🌰', 'تۆڤ', 'Samen', 'Seed'),
  TreeStage(20, '🌱', 'شینبوون', 'Keimling', 'Sprout'),
  TreeStage(60, '🌿', 'رووەکێ بچووک', 'Kleine Pflanze', 'Small Plant'),
  TreeStage(150, '🪴', 'نەمام', 'Setzling', 'Sapling'),
  TreeStage(300, '🌳', 'دارا گەنج', 'Junger Baum', 'Young Tree'),
  TreeStage(600, '🌳', 'دار', 'Baum', 'Tree'),
  TreeStage(1200, '🌲', 'دارا مەزن', 'Großer Baum', 'Big Tree'),
  TreeStage(2500, '🍎', 'دارا بەردار', 'Fruchtbaum', 'Fruit Tree'),
];

class TreeCard extends StatefulWidget {
  final int xp;
  final AppLanguage lang;
  const TreeCard({super.key, required this.xp, required this.lang});

  @override
  State<TreeCard> createState() => _TreeCardState();
}

class _TreeCardState extends State<TreeCard> {
  bool showStages = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.lang;
    final xp = widget.xp;
    var stage = 0;
    for (var i = 0; i < treeStages.length; i++) {
      if (xp >= treeStages[i].xp) stage = i;
    }
    final last = stage == treeStages.length - 1;
    final from = treeStages[stage].xp;
    final to = last ? from : treeStages[stage + 1].xp;
    final inStage = last ? 1.0 : ((xp - from) / (to - from)).clamp(0.0, 1.0);
    final total = (xp / treeStages.last.xp).clamp(0.0, 1.0);
    final st = treeStages[stage];
    final hour = DateTime.now().hour;
    final night = hour >= 19 || hour < 6;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tr(n, 'دارا تە', 'Dein Baum', 'Your tree'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(tr(n, 'قۆناغ ${stage + 1} ژ ٨', 'Stufe ${stage + 1} von 8', 'Stage ${stage + 1} of 8'),
              style: const TextStyle(color: Colors.white60)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1.25,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: inStage),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, g, __) => CustomPaint(painter: TreePainter(stage: stage, growth: g, night: night)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Text(st.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Text(tr(n, st.ku, st.de, st.en), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total,
            minHeight: 12,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation(AppColors.blue),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text(tr(n, 'مەزنبوون: ${(total * 100).round()}%', 'Wachstum: ${(total * 100).round()} %', 'Tree growth: ${(total * 100).round()} %'),
              style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          if (!last)
            Text(
                tr(n, '$xp / $to XP ➔ ${treeStages[stage + 1].ku}', '$xp / $to XP ➔ ${treeStages[stage + 1].de}',
                    '$xp / $to XP to ${treeStages[stage + 1].en}'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => setState(() => showStages = !showStages),
          icon: Icon(showStages ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          label: Text(tr(n, 'دارا تە چەوا مەزن دبیت؟', 'Wie dein Baum wächst', 'How your tree grows')),
        ),
        if (showStages) ...[
          Text(
              tr(n, 'هەر XPیەکا تو ژ وانە و یاریان وەردگری، دارا تە ئاڤ ددەت.',
                  'Jedes XP aus Lektionen und Spielen gießt deinen Baum.', 'Every XP from lessons and games waters your tree.'),
              style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 6),
          for (var i = 0; i < treeStages.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Text(treeStages[i].emoji, style: TextStyle(fontSize: 20, color: i <= stage ? null : Colors.white24)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(tr(n, treeStages[i].ku, treeStages[i].de, treeStages[i].en),
                        style: TextStyle(fontWeight: i == stage ? FontWeight.bold : FontWeight.normal, color: i <= stage ? Colors.white : Colors.white38))),
                Text('${treeStages[i].xp} XP', style: const TextStyle(color: Colors.white54)),
              ]),
            ),
        ],
      ]),
    );
  }
}

/// وێنەکێشانا دارێ — ل دویڤ قۆناغێ مەزن دبیت
class TreePainter extends CustomPainter {
  final int stage;
  final double growth; // 0..1 د ناڤ قۆناغێ دا
  final bool night;
  TreePainter({required this.stage, required this.growth, required this.night});

  static const _leaf = Color(0xFF3DDC84);
  static const _leafDark = Color(0xFF1FA463);
  static const _bark = Color(0xFF8B5A2B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night ? const [Color(0xFF0E1B2E), Color(0xFF15322B)] : const [Color(0xFF2B6E9E), Color(0xFF6FC3E8)],
        ).createShader(rect),
    );
    final rnd = Random(7);
    if (night) {
      final star = Paint()..color = Colors.white.withValues(alpha: 0.7);
      for (var i = 0; i < 14; i++) {
        canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.5), rnd.nextDouble() * 1.8 + 0.6, star);
      }
      final moon = Offset(w * 0.82, h * 0.17);
      canvas.drawCircle(moon, h * 0.08, Paint()..color = const Color(0xFFF1F1E6));
      canvas.drawCircle(moon + Offset(-h * 0.035, -h * 0.02), h * 0.075,
          Paint()..color = const Color(0xFF0F1D2F));
    } else {
      final sun = Offset(w * 0.82, h * 0.18);
      canvas.drawCircle(sun, h * 0.12, Paint()..color = const Color(0x55FFE066));
      canvas.drawCircle(sun, h * 0.075, Paint()..color = const Color(0xFFFFD84D));
    }
    // 🟢 ئەرد
    final groundY = h * 0.86;
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, groundY + h * 0.03), width: w * 0.72, height: h * 0.11),
        Paint()..color = const Color(0xFF1E6B3A));
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, groundY), width: w * 0.28, height: h * 0.06),
        Paint()..color = const Color(0xFF7A4B2A));
    final grass = Paint()
      ..color = _leaf
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final x in [0.25, 0.31, 0.37, 0.63, 0.69, 0.75]) {
      final gx = w * x, gy = groundY + h * 0.03;
      canvas.drawLine(Offset(gx - 4, gy), Offset(gx, gy - 10), grass);
      canvas.drawLine(Offset(gx + 4, gy), Offset(gx, gy - 10), grass);
    }

    final base = Offset(w / 2, groundY);
    final t = ((stage + growth) / treeStages.length).clamp(0.0, 1.0);

    if (stage == 0) {
      // 🌰 تۆڤ
      final r = h * (0.035 + 0.02 * growth);
      canvas.drawOval(Rect.fromCenter(center: base.translate(0, -r * 0.6), width: r * 2.2, height: r * 1.6),
          Paint()..color = const Color(0xFFA0663A));
      if (growth > 0.5) {
        canvas.drawLine(base.translate(0, -r * 1.2), base.translate(0, -r * 2.2), grass..strokeWidth = 3);
      }
      return;
    }

    if (stage <= 3) {
      // 🌱 شینبوون / رووەک / نەمام: ستوونەکێ کەسک و جووتێن پەلکان
      final stemH = h * (0.18 + 0.12 * stage + 0.1 * growth);
      final stem = Paint()
        ..color = stage == 3 ? const Color(0xFF6B8E23) : _leafDark
        ..strokeWidth = 4 + stage * 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final top = base.translate(0, -stemH);
      final path = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx + 8, base.dy - stemH / 2, top.dx, top.dy);
      canvas.drawPath(path, stem);
      final pairs = 1 + stage + (growth * 1.5).floor();
      for (var i = 0; i < pairs; i++) {
        final y = base.dy - stemH * (0.35 + 0.6 * i / max(1, pairs));
        final s = h * (0.045 + 0.015 * stage) * (1 - i * 0.06);
        _leafShape(canvas, Offset(base.dx + 3, y), s, -0.7);
        _leafShape(canvas, Offset(base.dx - 1, y - s * 0.4), s, pi + 0.7);
      }
      _leafShape(canvas, top, h * 0.05, -pi / 2);
      return;
    }

    // 🌳 دار: شاخێن دووبارەبوو
    final trunkH = h * (0.22 + 0.2 * t);
    final depth = min(stage + 1, 7);
    final leaves = <Offset>[];
    void branch(Offset from, double angle, double len, double width, int d) {
      final to = from + Offset(cos(angle) * len, sin(angle) * len);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = _bark
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
      if (d == 0) {
        leaves.add(to);
        return;
      }
      final spread = 0.42 + rnd.nextDouble() * 0.12;
      branch(to, angle - spread, len * 0.72, width * 0.68, d - 1);
      branch(to, angle + spread, len * 0.72, width * 0.68, d - 1);
      if (d > 3 && rnd.nextBool()) leaves.add(to);
    }

    branch(base, -pi / 2, trunkH * 0.55, 8 + 10 * t, depth - 2);
    final leafR = h * (0.04 + 0.02 * t);
    for (final l in leaves) {
      canvas.drawCircle(l, leafR * 1.25, Paint()..color = _leafDark.withValues(alpha: 0.9));
    }
    for (final l in leaves) {
      canvas.drawCircle(l.translate(-leafR * 0.3, -leafR * 0.3), leafR, Paint()..color = _leaf);
    }
    if (stage == treeStages.length - 1) {
      final fruit = Paint()..color = const Color(0xFFFF4B4B);
      for (var i = 0; i < leaves.length; i += 3) {
        canvas.drawCircle(leaves[i].translate(leafR * 0.4, leafR * 0.5), leafR * 0.35, fruit);
      }
    }
  }

  void _leafShape(Canvas c, Offset at, double s, double angle) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(s * 0.9, -s * 0.6, s * 1.8, 0)
      ..quadraticBezierTo(s * 0.9, s * 0.6, 0, 0);
    c.drawPath(path, Paint()..color = _leaf);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant TreePainter old) => old.stage != stage || old.growth != growth || old.night != night;
}

// ───────── ⏱️ دەمێ خواندنێ (٧ رۆژ) ─────────
const _dayShort = ['دوو', 'سێ', 'چار', 'پێنج', 'ئەینی', 'شەمبی', 'ئێک'];
const _monthKu = ['کانوونا٢', 'شوبات', 'ئادار', 'نیسان', 'گولان', 'حوزەیران', 'تەممووز', 'تەباخ', 'ئەیلوول', 'چریا١', 'چریا٢', 'کانوونا١'];

String _dayName(DateTime d, AppLanguage n) {
  const de = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final i = d.weekday - 1;
  return tr(n, _dayShort[i], de[i], en[i]);
}

class StudyChart extends StatelessWidget {
  final ProgressService p;
  const StudyChart({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final n = p.nativeLang;
    final today = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    final mins = [for (final d in days) (p.secondsOn(d) / 60).ceil()];
    final total = mins.fold(0, (a, b) => a + b);
    final top = max(1, mins.reduce(max));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: tr(n, 'دەمێ خواندنێ', 'Lernzeit', 'Study time'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          TextSpan(
              text: tr(n, '  ٧ رۆژێن دووماهیێ · $total خولەک', '  letzte 7 Tage · $total Min', '  last 7 days · $total min'),
              style: const TextStyle(color: Colors.white54)),
        ])),
        const SizedBox(height: 16),
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 150,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${mins[i]}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: mins[i] / top),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Container(
                        height: 4 + 96 * v,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: mins[i] > 0 ? AppColors.blue : Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(i == 6 ? tr(n, 'ئەڤرۆ', 'Heute', 'Today') : _dayName(days[i], n),
                        style: TextStyle(fontSize: 12, color: i == 6 ? Colors.white : Colors.white54, fontWeight: i == 6 ? FontWeight.bold : null)),
                  ]),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ───────── 📅 رۆژێن ڤێبوونێ (٢٠ حەفتی) ─────────
class PracticeHeatmap extends StatelessWidget {
  final ProgressService p;
  const PracticeHeatmap({super.key, required this.p});

  static const weeks = 20;

  Color _level(int xp) {
    if (xp <= 0) return Colors.white.withValues(alpha: 0.06);
    if (xp < 15) return AppColors.blue.withValues(alpha: 0.35);
    if (xp < 35) return AppColors.blue.withValues(alpha: 0.55);
    if (xp < 70) return AppColors.blue.withValues(alpha: 0.8);
    return AppColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final n = p.nativeLang;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1) - (weeks - 1) * 7);
    DateTime dayAt(int offset) => DateTime(firstMonday.year, firstMonday.month, firstMonday.day + offset);
    const rowLabels = {0: ('دوو', 'Mo', 'Mon'), 2: ('چار', 'Mi', 'Wed'), 4: ('ئەینی', 'Fr', 'Fri')};
    const deMonths = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    const enMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: tr(n, 'رۆژێن ڤێبوونێ', 'Übungstage', 'Days of practice'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          TextSpan(text: tr(n, '  ٢٠ حەفتیێن دووماهیێ', '  letzte 20 Wochen', '  last 20 weeks'), style: const TextStyle(color: Colors.white54)),
        ])),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: LayoutBuilder(builder: (context, box) {
            const labelW = 40.0;
            final cell = ((box.maxWidth - labelW) / weeks).floorToDouble();
            final gap = cell * 0.16;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ناڤێن هەیڤان
              SizedBox(
                height: 18,
                child: Stack(children: [
                  for (var w = 0; w < weeks; w++)
                    if (w == 0 || dayAt(w * 7).month != dayAt((w - 1) * 7).month)
                      Positioned(
                        left: labelW + w * cell,
                        child: Text(
                          () {
                            final m = dayAt(w * 7).month - 1;
                            return tr(n, _monthKu[m], deMonths[m], enMonths[m]);
                          }(),
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ),
                ]),
              ),
              for (var r = 0; r < 7; r++)
                Row(children: [
                  SizedBox(
                    width: labelW,
                    child: Text(rowLabels[r] == null ? '' : tr(n, rowLabels[r]!.$1, rowLabels[r]!.$2, rowLabels[r]!.$3),
                        style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ),
                  for (var w = 0; w < weeks; w++)
                    () {
                      final d = dayAt(w * 7 + r);
                      final future = d.isAfter(today);
                      final isToday = d == today;
                      return Container(
                        width: cell - gap,
                        height: cell - gap,
                        margin: EdgeInsets.only(right: gap, bottom: gap),
                        decoration: BoxDecoration(
                          color: future ? Colors.transparent : _level(p.xpOn(d)),
                          borderRadius: BorderRadius.circular(cell * 0.22),
                          border: isToday ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                      );
                    }(),
                ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(tr(n, 'کێم', 'Weniger', 'Less'), style: const TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(width: 6),
                for (final x in [0, 10, 20, 50, 80])
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(color: _level(x), borderRadius: BorderRadius.circular(4)),
                  ),
                const SizedBox(width: 2),
                Text(tr(n, 'پتر', 'Mehr', 'More'), style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ]),
            ]);
          }),
        ),
      ]),
    );
  }
}

// ───────── 🧮 کارتێن ئامارێ ─────────
class StatTiles extends StatelessWidget {
  final ProgressService p;
  const StatTiles({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final n = p.nativeLang;
    final mins = (p.totalSeconds / 60).round();
    final tiles = <(String, String, String)>[
      ('🔥', tr(n, '${p.streak} رۆژ', '${p.streak} Tage', '${p.streak} days'), tr(n, 'Streak یا نوکە', 'Aktuelle Serie', 'Current streak')),
      ('🏆', tr(n, '${p.bestStreak} رۆژ', '${p.bestStreak} Tage', '${p.bestStreak} days'), tr(n, 'درێژترین Streak', 'Längste Serie', 'Longest streak')),
      ('⏱️', tr(n, '$mins خولەک', '$mins Min', '$mins min'), tr(n, 'هەمی دەمێ خواندنێ', 'Gesamte Lernzeit', 'Total study time')),
      ('📅', '${p.daysPracticed}', tr(n, 'رۆژێن ڤێبوونێ', 'Übungstage', 'Days of practice')),
      ('✅', '${p.correctTotal}', tr(n, 'بەرسڤێن دروست', 'Richtige Antworten', 'Correct answers')),
      ('❌', '${p.wrongTotal}', tr(n, 'بەرسڤێن خەلەت', 'Falsche Antworten', 'Wrong answers')),
      ('🎯', '${p.accuracy} %', tr(n, 'دروستی', 'Genauigkeit', 'Accuracy')),
      ('📘', '${p.completedUnits.length}', tr(n, 'قۆناغێن تەمامکری', 'Kapitel fertig', 'Chapters finished')),
      ('💡', '${p.wordsLearned}', tr(n, 'پەیڤێن فێربووی', 'Gelernte Wörter', 'Words learned')),
      ('⚡', '${p.xp}', 'XP', ),
    ];
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final (emoji, value, label) in tiles)
          Container(
            width: w,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: _cardBox(),
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  ),
                  Text(label, maxLines: 2, style: const TextStyle(fontSize: 13, color: Colors.white60)),
                ]),
              ),
            ]),
          ),
      ]);
    });
  }
}
