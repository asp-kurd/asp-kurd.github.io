import 'package:flutter/material.dart';

import '../../data/curriculum.dart';
import '../../models.dart';
import '../../services/progress_service.dart';
import '../../ui.dart';
import '../settings_screen.dart';
import 'game_kind.dart';
import 'game_session.dart';

/// 🎮 تابا یاریان — وەکی «Let's play with words»
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final n = p.nativeLang;
        final due = p.dueConcepts;
        final weak = p.weakConcepts;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
            children: [
              Row(children: [
                Expanded(
                  child: Text(tr(n, 'کێمەکێ ڤێبوون، هەر رۆژ', 'Ein bisschen Übung, jeden Tag', 'A little practice, every day'),
                      style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ]),
              Text(tr(n, 'بلا ب پەیڤان یاری بکەین ✨', 'Lass uns mit Wörtern spielen ✨', "Let's play with words ✨"),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 6),
              Text(
                  tr(n, 'وێنە، دەنگ و یاریێن بچووک. یاریەکێ بدۆزە کو حەز ژێ دکەی.',
                      'Bilder, Töne und kleine Spiele. Finde ein Spiel, das dir gefällt.',
                      'Pictures, sounds and small challenges. Find a game you enjoy.'),
                  style: const TextStyle(color: Colors.white60, fontSize: 15)),
              const SizedBox(height: 18),
              _heroCard(context, n),
              const SizedBox(height: 12),
              _practiceTile(
                context,
                icon: Icons.autorenew_rounded,
                color: AppColors.green,
                title: tr(n, 'دووبارەکرنا ب دەم', 'Wiederholung', 'Spaced Repetition'),
                subtitle: due.isEmpty
                    ? tr(n, 'نوکە چو پەیڤ نینن — سوبەهی دێ زڤڕن', 'Heute nichts fällig', 'Nothing due right now')
                    : tr(n, 'ئەڤ پەیڤە دڤێت ئەڤرۆ بهێنە دووبارەکرن', 'Diese Wörter sind heute fällig', 'These words are due today'),
                count: due.length,
                onTap: due.isEmpty ? null : () => _openMixed(context, due.take(10).toList()),
              ),
              _practiceTile(
                context,
                icon: Icons.highlight_off_rounded,
                color: AppColors.red,
                title: tr(n, 'پەیڤێن خەلەت', 'Fehlerwörter', 'Mistake Words'),
                subtitle: tr(n, 'ئەو پەیڤێن تە خەلەت کرین', 'Wörter mit Fehlern', 'Words you got wrong'),
                count: weak.length,
                onTap: weak.isEmpty ? null : () => _openMixed(context, weak.take(10).toList()),
              ),
              const SizedBox(height: 18),
              Text(tr(n, 'رێکێن دی یێن یاریێ', 'Mehr Spiele', 'More ways to play'),
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, box) {
                final w = (box.maxWidth - 12) / 2;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final g in GameKind.values) SizedBox(width: w, child: _gameCard(context, g, n, p)),
                ]);
              }),
            ],
          ),
        );
      },
    );
  }

  void _openMixed(BuildContext context, List<WordConcept> words) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GameSessionScreen(kind: null, concepts: words)));
  }

  Widget _heroCard(BuildContext context, AppLanguage n) {
    final preview = allConcepts.where((c) => c.emoji.isNotEmpty).take(40).toList()..shuffle();
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GamePathScreen(kind: GameKind.pickPicture))),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (final c in preview.take(3))
              Padding(padding: const EdgeInsetsDirectional.only(end: 14), child: Text(c.pic, style: const TextStyle(fontSize: 44))),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ]),
          const SizedBox(height: 10),
          Text(tr(n, 'جهەکێ باش بۆ دەستپێکێ', 'Ein guter Anfang', 'A good place to start'),
              style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
          Text(tr(n, 'ئاسانترین رێک', 'Einfachster Modus', 'Easiest Mode'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Wrap(spacing: 14, children: [
            _chip(Icons.visibility_rounded, tr(n, 'ببینە', 'Sehen', 'See')),
            _chip(Icons.volume_up_rounded, tr(n, 'گوهداری بکە', 'Hören', 'Hear')),
            _chip(Icons.touch_app_rounded, tr(n, 'هەلبژێرە', 'Wählen', 'Pick')),
          ]),
          const SizedBox(height: 6),
          Text(tr(n, 'ئێک وێنە. ئێک پەیڤ. ب لەزا خۆ.', 'Ein Bild. Ein Wort. Dein Tempo.', 'One picture. One word. Your pace.'),
              style: const TextStyle(color: Colors.white60)),
        ]),
      ),
    );
  }

  Widget _chip(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 18, color: AppColors.blue),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
      ]);

  Widget _practiceTile(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required int count,
      VoidCallback? onTap}) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: count > 0 ? color.withValues(alpha: 0.6) : Colors.transparent),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: count > 0 ? color : Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
        trailing: count > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _gameCard(BuildContext context, GameKind g, AppLanguage n, ProgressService p) {
    final stars = p.totalStars(g.id);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamePathScreen(kind: g))),
      child: Container(
        height: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: g.color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
              child: Text(g.emoji, style: const TextStyle(fontSize: 32)),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ]),
          const Spacer(),
          Text(g.title(n), maxLines: 2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(g.subtitle(n), maxLines: 2, style: const TextStyle(fontSize: 13, color: Colors.white54)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 3),
            Text('$stars / ${appCurriculum.length * 3}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ]),
        ]),
      ),
    );
  }
}

/// 🗺️ رێکا قۆناغان بۆ ئێک یاری — ب ٣ ستێران بۆ هەر قۆناغەکێ
class GamePathScreen extends StatelessWidget {
  final GameKind kind;
  const GamePathScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    return Directionality(
      textDirection: n.direction,
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Text(kind.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(child: Text(kind.title(n), style: TextStyle(color: kind.color, fontWeight: FontWeight.bold))),
          ]),
        ),
        body: ListenableBuilder(
          listenable: p,
          builder: (context, _) {
            final units = appCurriculum;
            var next = units.indexWhere((u) => p.starsFor(kind.id, u.id) == 0);
            if (next < 0) next = units.indexWhere((u) => p.starsFor(kind.id, u.id) < 3);
            final played = units.where((u) => p.starsFor(kind.id, u.id) > 0).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _play(context, next < 0 ? 0 : next),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kind.color, width: 2),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                          radius: 28,
                          backgroundColor: kind.color,
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(n, 'هەمی قۆناغ', 'Alle Kapitel', 'All chapters'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(tr(n, 'بەردەوام بە: $played / ${units.length} قۆناغ', 'Weiter: $played / ${units.length}',
                              'Continue: $played / ${units.length}'), style: const TextStyle(color: Colors.white60)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                _SnakePath(kind: kind, current: next, onTap: (i) => _play(context, i)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _play(BuildContext context, int i) {
    final u = appCurriculum[i];
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameSessionScreen(kind: kind, concepts: u.concepts, unit: u)),
    );
  }
}

/// رێکا مارێ (snake): ٢ قۆناغ د هەر ریزەکێ دا، ب خەتەکێ پێکڤە گرێدای
class _SnakePath extends StatelessWidget {
  final GameKind kind;
  final int current;
  final void Function(int) onTap;
  const _SnakePath({required this.kind, required this.current, required this.onTap});

  static const rowH = 200.0;
  static const nodeSize = 116.0;

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final n = p.nativeLang;
    final units = appCurriculum;
    final rows = (units.length + 1) ~/ 2;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        Offset center(int i) {
          final r = i ~/ 2;
          final leftFirst = r.isEven;
          final first = i.isEven;
          final x = (first == leftFirst) ? w * 0.27 : w * 0.73;
          return Offset(x, 70 + r * rowH);
        }

        final centers = [for (var i = 0; i < units.length; i++) center(i)];
        return SizedBox(
          height: rows * rowH + 20,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _PathPainter(centers, kind.color))),
            for (var i = 0; i < units.length; i++)
              Positioned(
                left: centers[i].dx - 80,
                top: centers[i].dy - 70,
                width: 160,
                child: _node(units[i], i, p.starsFor(kind.id, units[i].id), i == current, n),
              ),
          ]),
        );
      }),
    );
  }

  Widget _node(LessonUnit u, int i, int stars, bool isCurrent, AppLanguage n) {
    final pic = u.concepts.firstWhere((c) => c.emoji.isNotEmpty, orElse: () => u.concepts.first).pic;
    final title = u.title(n).replaceFirst(RegExp(r'^[^:]*:\s*'), '');
    return GestureDetector(
      onTap: () => onTap(i),
      child: Column(children: [
        SizedBox(
          height: 30,
          child: isCurrent
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: kind.color, borderRadius: BorderRadius.circular(10)),
                  child: Text(tr(n, 'دەستپێک', 'START', 'START'),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                )
              : StarRow(stars: stars, size: 18),
        ),
        const SizedBox(height: 4),
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF253740),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: isCurrent ? kind.color : (stars == 3 ? AppColors.gold : Colors.white12), width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Text(pic, style: const TextStyle(fontSize: 48)),
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: n.direction,
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        Text('$stars / 3 ⭐', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> pts;
  final Color color;
  _PathPainter(this.pts, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy + 10);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      if ((a.dy - b.dy).abs() < 1) {
        path.lineTo(b.dx, b.dy + 10);
      } else {
        // زڤڕین ل قەراخێ: کەوانەک ل دەرڤەی قۆناغان
        final side = a.dx > size.width / 2 ? size.width - 18 : 18.0;
        path.cubicTo(side, a.dy + 10, side, b.dy + 10, b.dx, b.dy + 10);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.pts != pts || old.color != color;
}
