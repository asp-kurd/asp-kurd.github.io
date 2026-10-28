import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'voice_clone_screen.dart';
import 'widgets/record_button.dart';

/// ستۆدیۆیا دەنگی: دەنگێ خۆ بۆ هەر پەیڤەکێ تۆمار بکە.
/// پشتی تۆمارکرنێ، د هەمی وانەیاندا دەنگێ تە دێ هێتە بکارئینان.
class VoiceStudioScreen extends StatefulWidget {
  const VoiceStudioScreen({super.key});

  @override
  State<VoiceStudioScreen> createState() => _VoiceStudioScreenState();
}

class _VoiceStudioScreenState extends State<VoiceStudioScreen> {
  final voice = VoiceService.instance;
  final progress = ProgressService.instance;
  late AppLanguage lang = progress.nativeLang; // بنەڕەت: بادینی، چونکی TTS بۆ بادینی نینە

  AppLanguage get ui => progress.nativeLang;

  Future<void> _onSaved(WordConcept c, bool wasNew) async {
    if (wasNew) await progress.addHeart(); // خەلات
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final done = voice.countRecordings(lang, allConcepts);
    final total = allConcepts.length;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr(ui, '🎙️ ستۆدیۆیا دەنگێ من', '🎙️ Mein Stimmstudio', '🎙️ My Voice Studio'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  tr(ui, 'دەست ب سەر 🎤 دا بگرە و پەیڤێ بێژە. دەنگێ تە دێ د وانەیاندا هێتە لێدان. هەر تۆمارەکا نوو = ❤️ +١',
                      'Halte 🎤 gedrückt und sprich. Deine Stimme wird in den Lektionen benutzt. Jede neue Aufnahme = ❤️ +1',
                      'Hold 🎤 and speak. Your voice is used in lessons. Each new recording = ❤️ +1'),
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 12),
                // 🧬 دەروازەیا کلۆنکرنا دەنگی
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceCloneScreen()));
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF1CB0F6)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      const Text('🧬', style: TextStyle(fontSize: 30)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(ui, 'کلۆنکرنا دەنگێ من ب AI', 'Meine Stimme mit KI klonen', 'Clone my voice with AI'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          Text(tr(ui, '١٥ چرکە دەنگ ➔ هەمی وانە ب ٣ زمانان', '15 Sek. ➔ alle Lektionen in 3 Sprachen',
                                  '15 sec ➔ every lesson in 3 languages'),
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<AppLanguage>(
                  segments: AppLanguage.values
                      .map((l) => ButtonSegment(value: l, label: Text('${l.flag} ${l.code.toUpperCase()}')))
                      .toList(),
                  selected: {lang},
                  onSelectionChanged: (s) => setState(() => lang = s.first),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : done / total,
                          minHeight: 10,
                          backgroundColor: AppColors.card,
                          valueColor: const AlwaysStoppedAnimation(AppColors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$done / $total', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: done == total
                      ? null
                      : () async {
                          await Navigator.push(
                              context, MaterialPageRoute(builder: (_) => QuickRecordScreen(lang: lang, ui: ui)));
                          if (mounted) setState(() {});
                        },
                  icon: const Icon(Icons.flash_on_rounded),
                  label: Text(tr(ui, 'تۆمارکرنا خێرا (ئێک ب ئێک)', 'Schnellaufnahme', 'Quick record (one by one)')),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: appCurriculum.map((unit) {
                final unitDone = voice.countRecordings(lang, unit.concepts);
                return Card(
                  color: AppColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ExpansionTile(
                    shape: const Border(),
                    leading: CircleAvatar(backgroundColor: unit.color, child: Icon(unit.icon, color: Colors.white)),
                    title: Text(unit.title(ui), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('🎤 $unitDone / ${unit.concepts.length}'),
                    children: unit.concepts.map((c) => _row(c)).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(WordConcept c) {
    final has = voice.hasRecording(lang, c.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // ✓ = تۆمارێ تە، 🧬 = دەنگێ کلۆنکری، ○ = چ نینە
          if (has)
            const Icon(Icons.check_circle, color: AppColors.green, size: 20)
          else if (voice.inMyVoice(c, lang))
            InkWell(
              onTap: () => voice.speak(c, lang),
              child: const Text('🧬', style: TextStyle(fontSize: 17)),
            )
          else
            const Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.text(lang), textDirection: lang.direction,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(c.hint(lang), style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
          if (has) ...[
            IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.blue),
              onPressed: () => voice.playFile(voice.pathFor(lang, c.id)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
              onPressed: () async {
                await voice.deleteRecording(lang, c.id);
                setState(() {});
              },
            ),
          ],
          RecordButton(
            size: 40,
            onStart: () => voice.startRecording(lang: lang, conceptId: c.id),
            onStop: () async {
              final p = await voice.stopRecording();
              if (p != null) {
                await voice.playFile(p);
                await _onSaved(c, !has);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// تۆمارکرنا خێرا: پەیڤێن بێ دەنگ ئێک ل دویف ئێکێ نیشان ددەت
class QuickRecordScreen extends StatefulWidget {
  final AppLanguage lang;
  final AppLanguage ui;
  const QuickRecordScreen({super.key, required this.lang, required this.ui});

  @override
  State<QuickRecordScreen> createState() => _QuickRecordScreenState();
}

class _QuickRecordScreenState extends State<QuickRecordScreen> {
  final voice = VoiceService.instance;
  late final List<WordConcept> todo = allConcepts.where((c) => !voice.hasRecording(widget.lang, c.id)).toList();
  int i = 0;
  bool justSaved = false;

  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    if (i >= todo.length) {
      return Directionality(
        textDirection: ui.direction,
        child: Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🎉', style: TextStyle(fontSize: 80)),
              Text(tr(ui, 'هەمی پەیڤ هاتنە تۆمارکرن!', 'Alles aufgenommen!', 'All words recorded!'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );
    }
    final c = todo[i];
    final lang = widget.lang;
    return Directionality(
      textDirection: ui.direction,
      child: Scaffold(
        appBar: AppBar(title: Text('${i + 1} / ${todo.length}')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(c.text(lang), textAlign: TextAlign.center, textDirection: lang.direction,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(c.hint(lang), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.blue, fontSize: 16)),
              if (lang != ui) ...[
                const SizedBox(height: 6),
                Text(c.text(ui), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
              ],
              const Spacer(),
              Center(
                child: RecordButton(
                  size: 110,
                  hintText: tr(ui, 'دەست ب سەر دا بگرە و بێژە', 'Gedrückt halten und sprechen', 'Hold and speak'),
                  onStart: () => voice.startRecording(lang: lang, conceptId: c.id),
                  onStop: () async {
                    final p = await voice.stopRecording();
                    if (p == null) return;
                    if (!justSaved) await ProgressService.instance.addHeart();
                    await voice.playFile(p);
                    setState(() => justSaved = true);
                  },
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        i++;
                        justSaved = false;
                      }),
                      child: Text(tr(ui, 'دەرباز بکە', 'Überspringen', 'Skip')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                      onPressed: justSaved
                          ? () => setState(() {
                                i++;
                                justSaved = false;
                              })
                          : null,
                      child: Text(tr(ui, 'یا دیتر ➔', 'Weiter ➔', 'Next ➔')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
