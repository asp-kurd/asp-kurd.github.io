import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/speech_score.dart';
import '../../services/speech_stub.dart' if (dart.library.js_interop) '../../services/speech_web.dart';
import '../../ui.dart';
import 'sound_wave.dart';

export '../../services/speech_stub.dart' if (dart.library.js_interop) '../../services/speech_web.dart' show speechSupported;

/// 🎤 «بێژە» ➔ ئەپ گوهداری دکەت و پەیڤ ب پەیڤ نیشان ددەت کا دروست بوون یان نە
class SpeakCheck extends StatefulWidget {
  final String target;
  final AppLanguage lang;
  final void Function(SpeechScore score)? onResult;
  const SpeakCheck({super.key, required this.target, required this.lang, this.onResult});

  @override
  State<SpeakCheck> createState() => _SpeakCheckState();
}

class _SpeakCheckState extends State<SpeakCheck> {
  final _l = SpeechListener();
  bool listening = false;
  SpeechScore? score;

  @override
  void didUpdateWidget(covariant SpeakCheck old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) score = null;
  }

  @override
  void dispose() {
    _l.stop();
    super.dispose();
  }

  Future<void> _go() async {
    if (listening) {
      _l.stop();
      return;
    }
    setState(() {
      listening = true;
      score = null;
    });
    final heard = await _l.listen(widget.lang.ttsCode ?? 'de-DE');
    if (!mounted) return;
    final s = scoreSpeech(widget.target, heard);
    setState(() {
      listening = false;
      score = s;
    });
    widget.onResult?.call(s);
  }

  @override
  Widget build(BuildContext context) {
    final s = score;
    final color = s == null ? AppColors.blue : (s.percent >= 80 ? AppColors.green : (s.percent >= 50 ? AppColors.gold : AppColors.red));
    return Column(children: [
      GestureDetector(
        onTap: _go,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: listening ? 112 : 96,
          height: listening ? 112 : 96,
          decoration: BoxDecoration(
            color: listening ? AppColors.red : AppColors.blue,
            shape: BoxShape.circle,
            boxShadow: [if (listening) BoxShadow(color: AppColors.red.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 4)],
          ),
          child: Center(child: SoundWave(active: listening, size: 52)),
        ),
      ),
      const SizedBox(height: 8),
      Text(listening ? '👂 گوهداری دکەم… باخڤە' : (s == null ? 'بکە تپ و بێژە' : 'بکە تپ دا دیسا بێژی'),
          style: TextStyle(color: AppColors.fg60)),
      if (s != null) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 2)),
          child: Column(children: [
            Text(
              s.heard.isEmpty
                  ? '🤔 من چ تشت نەبهیست — دیسا هەول بدە'
                  : (s.percent >= 80 ? '🌟 نایاب! ${s.percent}٪' : (s.percent >= 50 ? '👍 باشە! ${s.percent}٪ — دیسا هەول بدە' : '💪 ${s.percent}٪ — گوهداری بکە و دیسا بێژە')),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: color),
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 4, children: [
                for (final (w, ok) in s.words)
                  Text(w, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ok ? AppColors.green : AppColors.red,
                      decoration: ok ? null : TextDecoration.underline)),
              ]),
            ),
            if (s.heard.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('من بهیست: «${s.heard}»', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.fg54)),
            ],
          ]),
        ),
      ],
    ]);
  }
}
