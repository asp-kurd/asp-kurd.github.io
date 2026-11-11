import 'dart:math';

import 'package:flutter/material.dart';

import '../data/cloze_bank.dart';
import '../data/curriculum.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/rewards_service.dart';
import '../services/sfx.dart';
import '../ui.dart';
import 'widgets/reward_fx.dart';

/// 🪙 ل بن هەر ئەزموونەکێ: پشتی تەمامکرنا ئەزموونێ، دیناردەک دیار دبیت.
/// ئێک پرسیارا کەمەکێ زەحمەتتر · ٣ هەولدان · دروست ➔ ١٠ دینار · پاشان نامینیت.
class ExamCoinNode extends StatefulWidget {
  final String examId; // بۆ نموونە lek_3
  final int section;
  const ExamCoinNode({super.key, required this.examId, required this.section});

  @override
  State<ExamCoinNode> createState() => _ExamCoinNodeState();
}

class _ExamCoinNodeState extends State<ExamCoinNode> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    if (p.examBest(widget.examId) == null || RewardsService.instance.coinDone(widget.examId)) return const SizedBox.shrink();
    final n = p.nativeLang;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Center(
        child: GestureDetector(
          onTap: () => _open(context),
          child: AnimatedBuilder(
            animation: c,
            builder: (_, child) => Transform.translate(offset: Offset(0, -6 * sin(c.value * 2 * pi).abs()), child: child),
            child: Column(children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.55), blurRadius: 28, spreadRadius: 2)],
                ),
                child: Image.asset('assets/img/fx/coin.webp'),
              ),
              const SizedBox(height: 6),
              Text(tr(n, 'پرسیارا دیاریێ · +${RewardsService.examCoinReward} 🪙', 'Bonusfrage · +10 🪙', 'Bonus question · +10 🪙'),
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.goldText)),
            ]),
          ),
        ),
      ),
    );
  }

  /// پرسیارەکا کەمەکێ زەحمەتتر ژ قۆناغێن ڤێ وانێ
  (String, String, String, List<String>) _question() {
    final p = ProgressService.instance;
    final t = p.targetLang;
    final rng = Random();
    final units = appCurriculum.where((u) => u.section == widget.section).toList();
    final bank = [for (final u in units) ...clozeBankFor(u.id, t)]..shuffle(rng);
    bank.sort((a, b) => (b.multi ? 1 : 0) - (a.multi ? 1 : 0)); // پێشی یێن ب ٢ جهێن ڤالا
    if (bank.isNotEmpty) {
      final e = bank.first.info;
      final opts = {e.answer, ...e.distractors}.toList();
      // جوابێن دی ژ رستێن دی ژی (زەحمەتتر)
      for (final o in bank.skip(1)) {
        if (opts.length >= 4) break;
        if (o.multi == bank.first.multi && !opts.contains(o.info.answer)) opts.add(o.info.answer);
      }
      return (e.sentence, '', e.answer, opts..shuffle(rng));
    }
    // ئەگەر رستە نەبن: وەرگێڕانا رستەکێ (ژ کوردی ➔ زمانێ فێربوونێ)
    final cs = [for (final u in units) ...u.concepts]..sort((a, b) => b.text(t).length.compareTo(a.text(t).length));
    final c = cs.take(4).toList()[rng.nextInt(min(4, cs.length))];
    final opts = <String>{c.text(t)};
    for (final d in cs..shuffle(rng)) {
      if (opts.length >= 4) break;
      opts.add(d.text(t));
    }
    return (c.ku, '', c.text(t), opts.toList()..shuffle(rng));
  }

  Future<void> _open(BuildContext context) async {
    final n = ProgressService.instance.nativeLang;
    final t = ProgressService.instance.targetLang;
    final (q, _, answer, options) = _question();
    final wrong = <String>{};
    var won = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final left = 3 - wrong.length;
          final over = won || left <= 0;
          return Directionality(
            textDirection: n.direction,
            child: AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(children: [
                Image.asset('assets/img/fx/coin_s.webp', width: 34),
                const SizedBox(width: 8),
                Expanded(child: Text(tr(n, 'پرسیارا دیاریێ', 'Bonusfrage', 'Bonus question'), style: const TextStyle(fontWeight: FontWeight.w900))),
                Text(over ? '' : '❤️' * left, style: const TextStyle(fontSize: 16)),
              ]),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(q,
                      textAlign: TextAlign.center,
                      textDirection: q.contains('___') ? t.direction : n.direction,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, height: 1.5)),
                  const SizedBox(height: 14),
                  for (final o in options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OptionTile(
                        text: o,
                        selected: false,
                        textDirection: t.direction,
                        stateColor: (over && o == answer)
                            ? AppColors.green
                            : wrong.contains(o)
                                ? AppColors.red
                                : null,
                        onTap: over || wrong.contains(o)
                            ? null
                            : () {
                                if (o == answer) {
                                  Sfx.correct();
                                  set(() => won = true);
                                } else {
                                  Sfx.wrong();
                                  set(() => wrong.add(o));
                                }
                              },
                      ),
                    ),
                  if (over)
                    Text(
                      won
                          ? tr(n, '🎉 دروستە! +${RewardsService.examCoinReward} دینار', '🎉 Richtig! +10 Dinar', '🎉 Correct! +10 dinars')
                          : tr(n, 'ئەڤ جارە نەبوو — بەرسڤا دروست ب کەسکی یە', 'Leider nicht – die richtige Antwort ist grün',
                              'Not this time – the right answer is green'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, color: won ? AppColors.green : AppColors.red),
                    )
                  else
                    Text(tr(n, '$left هەولدان ماینە', '$left Versuche', '$left tries left'),
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg60)),
                ]),
              ),
              actions: [
                if (over)
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr(n, 'باشە', 'OK', 'OK')),
                  ),
              ],
            ),
          );
        },
      ),
    );
    await RewardsService.instance.finishCoin(widget.examId, won);
    if (mounted) setState(() {});
    if (context.mounted) await showPendingRewards(context);
  }
}
