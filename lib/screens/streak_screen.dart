import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/progress_service.dart';
import '../services/sfx.dart';
import '../ui.dart';
import 'widgets/combo.dart' show kuNum;
import 'widgets/mascot.dart';

/// 🔥 ئەگەر ستریک ئەڤرۆ زێدە بوو (بۆ نموونە ٣ ➔ ٤)، شاشا ئاهەنگێ نیشان بدە.
/// [replace]: شاشا نوکە (ئەنجام) بگوهۆڕە، دا «بەردەوام بە» راستەوخۆ بزڤڕیتە سەرەکی.
Future<bool> maybeShowStreak(BuildContext context, {bool replace = false}) async {
  final ev = ProgressService.instance.takeStreakEvent();
  if (ev == null) return false;
  final route = MaterialPageRoute(builder: (_) => StreakScreen(from: ev.$1, to: ev.$2));
  if (replace) {
    await Navigator.pushReplacement(context, route);
  } else {
    await Navigator.push(context, route);
  }
  return true;
}

class StreakScreen extends StatefulWidget {
  final int from, to;
  const StreakScreen({super.key, required this.from, required this.to});
  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  late final AnimationController _flame = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  final _rng = Random();
  late final _sparks = List.generate(26, (_) => (_rng.nextDouble() * 2 * pi, 0.5 + _rng.nextDouble() * 0.6, _rng.nextInt(3)));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1150), Sfx.star);
  }

  @override
  void dispose() {
    _c.dispose();
    _flame.dispose();
    super.dispose();
  }

  AppLanguage get n => ProgressService.instance.nativeLang;
  String num(int v) => n == AppLanguage.badini ? kuNum(v) : '$v';

  @override
  Widget build(BuildContext context) {
    final to = widget.to;
    final title = to == 1
        ? tr(n, 'ستریکا تە دەستپێکر! 🔥', 'Deine Serie hat begonnen! 🔥', 'Your streak has started! 🔥')
        : tr(n, '${num(to)} رۆژ ل دویڤ ئێک! 🔥', '${num(to)} Tage in Folge! 🔥', '${num(to)}-day streak! 🔥');
    final sub = tr(n, 'سوبەهی ژی وەرە دا ئاگرێ تە نەڤەمریت 💪', 'Komm morgen wieder, damit dein Feuer brennt 💪',
        'Come back tomorrow to keep the fire burning 💪');

    return Directionality(
      textDirection: n.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1206),
        body: AnimatedBuilder(
          animation: Listenable.merge([_c, _flame]),
          builder: (context, _) {
            final t = _c.value;
            final grow = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
            final flip = Curves.easeInOutBack.transform(((t - 0.35) / 0.3).clamp(0.0, 1.0));
            final burst = ((t - 0.45) / 0.45).clamp(0.0, 1.0);
            final textIn = Curves.easeOut.transform(((t - 0.55) / 0.3).clamp(0.0, 1.0));
            final f = _flame.value;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.9 + 0.1 * f,
                  colors: [const Color(0xFFFF9600).withValues(alpha: 0.45 * grow), const Color(0xFF1A1206)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const Spacer(flex: 2),
                    SizedBox(
                      height: 300,
                      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                        // پریسک
                        for (final (ang, sp, kind) in _sparks)
                          if (burst > 0 && burst < 1)
                            Transform.translate(
                              offset: Offset(cos(ang) * 170 * sp * burst, sin(ang) * 150 * sp * burst - 30 * burst),
                              child: Opacity(
                                opacity: 1 - burst,
                                child: Text(['✨', '🔥', '⭐'][kind], style: TextStyle(fontSize: 16 + 8 * (1 - burst))),
                              ),
                            ),
                        // ئاگر
                        Transform.scale(
                          scale: (0.2 + 0.8 * grow) * (1 + 0.05 * f),
                          child: Transform.rotate(
                            angle: (f - 0.5) * 0.06,
                            child: Transform.translate(offset: const Offset(0, -40), child: Text('🔥',
                                style: TextStyle(fontSize: 170, shadows: [
                                  Shadow(color: const Color(0xFFFF9600).withValues(alpha: 0.9), blurRadius: 40 + 20 * f),
                                ]))),
                          ),
                        ),
                        // ژمارە: ٣ دچیتە ژۆر، ٤ دهێت
                        Positioned(
                          bottom: -6,
                          child: ClipRect(
                            child: SizedBox(
                              height: 96,
                              width: 200,
                              child: Stack(alignment: Alignment.center, children: [
                                if (widget.from > 0)
                                  Transform.translate(
                                    offset: Offset(0, -96 * flip),
                                    child: Opacity(opacity: 1 - flip, child: _num(widget.from)),
                                  ),
                                Transform.translate(
                                  offset: Offset(0, 96 * (1 - flip)),
                                  child: Opacity(opacity: widget.from > 0 ? flip : grow.clamp(0.0, 1.0), child: _num(to)),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: textIn,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - textIn)),
                        child: Column(children: [
                          Text(title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFFFFB020))),
                          const SizedBox(height: 8),
                          Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _week(t),
                    const Spacer(flex: 3),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      SizedBox(width: 90, height: 110, child: MascotView(char: MascotChar.forUser(), mood: MascotMood.happy, height: 110, lipSync: false)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BigButton(
                          label: tr(n, 'بەردەوام بە', 'Weiter', 'CONTINUE'),
                          color: AppColors.orange,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _num(int v) => Text(
        num(v),
        style: const TextStyle(
          fontSize: 80,
          height: 1.1,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: [
            Shadow(color: Color(0xFFB34700), blurRadius: 0, offset: Offset(0, 5)),
            Shadow(color: Color(0xAAFF9600), blurRadius: 24),
          ],
        ),
      );

  /// حەفت رۆژێن دویماهیێ — ئەڤرۆ ب ئاگری پڕ دبیت
  Widget _week(double t) {
    final p = ProgressService.instance;
    final now = DateTime.now();
    const ku = ['دووشەمب', 'سێشەمب', 'چارشەمب', 'پێنجشەمب', 'ئەینی', 'شەمبی', 'ئێکشەمب'];
    const de = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const en = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final fill = Curves.elasticOut.transform(((t - 0.6) / 0.35).clamp(0.0, 1.0));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var k = 6; k >= 0; k--)
            Builder(builder: (_) {
              final d = now.subtract(Duration(days: k));
              final isToday = k == 0;
              final done = isToday || p.studiedOn(d);
              final w = d.weekday - 1;
              final label = switch (n) { AppLanguage.badini => ku[w], AppLanguage.german => de[w], _ => en[w] };
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Text(n == AppLanguage.badini ? label.substring(0, min(3, label.length)) : label,
                    style: TextStyle(fontSize: 11, color: isToday ? const Color(0xFFFFB020) : Colors.white54, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Transform.scale(
                  scale: isToday ? 0.6 + 0.4 * fill : 1,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? const Color(0xFFFF9600) : Colors.white.withValues(alpha: 0.1),
                      boxShadow: isToday ? [BoxShadow(color: const Color(0xFFFF9600).withValues(alpha: 0.7 * fill), blurRadius: 14)] : null,
                    ),
                    child: done ? const Text('🔥', style: TextStyle(fontSize: 16)) : null,
                  ),
                ),
              ]);
            }),
        ],
      ),
    );
  }
}
