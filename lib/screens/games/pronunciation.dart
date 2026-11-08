import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/curriculum.dart';
import '../../models.dart';
import '../../services/progress_service.dart';
import '../../services/voice_service.dart';
import '../../ui.dart';
import '../widgets/combo.dart' show showXpPop;
import '../widgets/speak_check.dart';

/// 🗣️ راهێنانا گۆتنێ: رستێ گوهداری بکە، بێژە، و ئەپ دبێژیت کیژ پەیڤ دروست بوون
class PronunciationScreen extends StatefulWidget {
  const PronunciationScreen({super.key});
  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  final p = ProgressService.instance;
  late final AppLanguage target = p.targetLang.ttsCode != null ? p.targetLang : AppLanguage.german;
  late List<WordConcept> items;
  int i = 0, xp = 0;
  final Set<int> rewarded = {};

  @override
  void initState() {
    super.initState();
    final done = appCurriculum.where((u) => p.completedUnits.contains(u.id)).expand((u) => u.concepts);
    var pool = done.where((c) => c.letter == null && c.text(target).split(' ').length >= 2).toList();
    if (pool.length < 10) {
      pool = allConcepts.where((c) => c.letter == null && c.text(target).split(' ').length >= 2).take(60).toList();
    }
    items = (pool..shuffle(Random())).take(10).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    VoiceService.instance.stopPlayback();
    if (xp > 0) p.earn(xp);
    super.dispose();
  }

  void _listen([double rate = 1.0]) => VoiceService.instance.speak(items[i], target, rate: rate);

  void _next() {
    VoiceService.instance.stopPlayback();
    if (i + 1 >= items.length) {
      Navigator.pop(context);
      return;
    }
    setState(() => i++);
    _listen();
  }

  @override
  Widget build(BuildContext context) {
    final c = items[i];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🗣️ راهێنانا گۆتنێ'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(value: (i + 1) / items.length, minHeight: 6, backgroundColor: AppColors.card),
          ),
        ),
        body: SafeArea(
          child: !speechSupported
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('ئەڤ مۆبایلە/بڕاوزەرە پشتگیریا ناسینا دەنگی ناکەت.\nل iPhone ئەپێ ژ Safari ڤەکە.', textAlign: TextAlign.center, style: TextStyle(fontSize: 17)),
                  ),
                )
              : ListView(padding: const EdgeInsets.all(20), children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
                    child: Column(children: [
                      if (c.emoji.isNotEmpty) Text(c.pic, style: const TextStyle(fontSize: 52)),
                      Text(c.text(target), textAlign: TextAlign.center, textDirection: target.direction,
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.germanText)),
                      const SizedBox(height: 6),
                      Text(c.ku, textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg60)),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        FilledButton.icon(onPressed: _listen, icon: const Icon(Icons.volume_up_rounded), label: const Text('گوهداری')),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(onPressed: () => _listen(0.7), icon: const Text('🐢', style: TextStyle(fontSize: 20))),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  SpeakCheck(
                    key: ValueKey(i),
                    target: c.text(target),
                    lang: target,
                    onResult: (s) {
                      if (s.percent >= 80 && !rewarded.contains(i)) {
                        rewarded.add(i);
                        xp += 3;
                        showXpPop(context, 3);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  BigButton(label: i + 1 < items.length ? 'رستا دی ➜' : 'تەمام', onPressed: _next),
                ]),
        ),
      ),
    );
  }
}
