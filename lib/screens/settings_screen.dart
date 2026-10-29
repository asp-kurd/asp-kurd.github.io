import 'package:flutter/material.dart';

import '../models.dart';
import '../services/progress_service.dart';
import '../services/sfx.dart';
import '../services/voice_service.dart';
import '../ui.dart';

/// ⚙️ ڕێکخستن: دەنگ، دەنگێ زەلال، پیتێن کال
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final p = ProgressService.instance;
  final v = VoiceService.instance;
  List<Map<String, String>> voices = [];
  bool loadingVoices = true;

  AppLanguage get ttsLang => p.targetLang.ttsCode != null ? p.targetLang : AppLanguage.german;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    await v.init();
    var list = await v.voicesFor(ttsLang);
    if (list.isEmpty) {
      // ل وێبێ دەنگ ب درەنگی بار دبن
      await Future.delayed(const Duration(milliseconds: 800));
      list = await v.voicesFor(ttsLang);
    }
    if (mounted) {
      setState(() {
        voices = list.take(15).toList();
        loadingVoices = false;
      });
    }
  }

  String get _sample => switch (ttsLang) {
        AppLanguage.english => 'Hello! How are you today?',
        _ => 'Hallo! Wie geht es dir heute?',
      };

  @override
  Widget build(BuildContext context) {
    final n = p.nativeLang;
    return Directionality(
      textDirection: n.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(n, 'ڕێکخستن', 'Einstellungen', 'Settings'))),
        body: ListenableBuilder(
          listenable: p,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _header(tr(n, 'دەنگ و شێوە', 'Ton & Aussehen', 'Sound & look')),
              _switch('🔊', tr(n, 'دەنگێن یاریێ', 'Spielgeräusche', 'Game sounds'),
                  tr(n, 'دەنگێ دروست و خەلەت د یاریان دا', 'Töne für richtig und falsch', 'Sounds for right and wrong'), p.gameSounds, (x) {
                p.setGameSounds(x);
                if (x) Sfx.correct();
              }),
              _switch('😄', tr(n, 'دەنگێن کەنی', 'Lustige Töne', 'Funny sounds'),
                  tr(n, 'جار جار دەنگەکێ کەنی پشتی خەلەتیێ', 'Ab und zu ein lustiger Ton nach einem Fehler',
                      'A funny sound now and then after a mistake'),
                  p.funnySounds, p.setFunnySounds),
              _switch('👁️', tr(n, 'پیتێن کال', 'Blasse Buchstaben', 'Pale letters'),
                  tr(n, 'د «پەیڤێ بنڤیسە» دا پەیڤ ب کالی دیار دبیت', 'Zeigt das Wort blass beim Tippen', 'Show the word pale while typing'),
                  p.paleLetters, p.setPaleLetters),
              const SizedBox(height: 18),
              _header(tr(n, 'دەنگێ ئاخفتنێ (زەلال)', 'Sprachausgabe', 'Speech voice')),
              Text(
                  tr(n, 'لەزا دەنگی', 'Sprechtempo', 'Speaking speed'),
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              SegmentedButton<double>(
                segments: [
                  ButtonSegment(value: 0.32, label: Text(tr(n, '🐢 هێدی', '🐢 Langsam', '🐢 Slow'))),
                  ButtonSegment(value: 0.42, label: Text(tr(n, 'ئاسایی', 'Normal', 'Normal'))),
                  ButtonSegment(value: 0.52, label: Text(tr(n, '🐇 ب لەز', '🐇 Schnell', '🐇 Fast'))),
                ],
                selected: {_nearestRate(v.ttsRate)},
                onSelectionChanged: (s) async {
                  await v.setRate(s.first);
                  setState(() {});
                  v.speakText(_sample, ttsLang);
                },
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: Text('${ttsLang.flag}  ${tr(n, 'هەلبژارتنا دەنگی', 'Stimme wählen', 'Choose a voice')}',
                      style: const TextStyle(color: Colors.white70)),
                ),
                TextButton.icon(
                  onPressed: () => v.speakText(_sample, ttsLang),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(tr(n, 'گوهداری بکە', 'Anhören', 'Listen')),
                ),
              ]),
              if (loadingVoices)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              else ...[
                _voiceTile(null, tr(n, '✨ ئۆتۆماتیک (باشترین دەنگ)', '✨ Automatisch (beste Stimme)', '✨ Automatic (best voice)'), ''),
                for (final x in voices) _voiceTile(x['name'], x['name'] ?? '', x['locale'] ?? ''),
                if (voices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                        tr(n, 'ل سەر iPhone: ڕێکخستن ➔ Accessibility ➔ Spoken Content ➔ Voices ➔ German، دەنگەکێ «Enhanced» یان «Premium» دابەزینە.',
                            'iPhone: Einstellungen ➔ Bedienungshilfen ➔ Gesprochene Inhalte ➔ Stimmen ➔ Deutsch: eine „Premium“-Stimme laden.',
                            'iPhone: Settings ➔ Accessibility ➔ Spoken Content ➔ Voices ➔ German: download an Enhanced/Premium voice.'),
                        style: const TextStyle(color: Colors.white54)),
                  ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Text(
                    tr(n, '💡 بۆ دەنگەکێ هەرە زەلال ل iPhone: Settings ➔ Accessibility ➔ Spoken Content ➔ Voices ➔ German ➔ «Anna (Premium)» یان «Helena (Enhanced)» دابەزینە، پاشان ل ڤێرە هەلبژێرە.',
                        '💡 Für die klarste Stimme auf dem iPhone eine Premium-/Enhanced-Stimme herunterladen und hier wählen.',
                        '💡 For the clearest voice on iPhone, download a Premium/Enhanced German voice in Spoken Content and pick it here.'),
                    style: const TextStyle(color: Colors.white70, height: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _nearestRate(double r) {
    const opts = [0.32, 0.42, 0.52];
    return opts.reduce((a, b) => (a - r).abs() <= (b - r).abs() ? a : b);
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      );

  Widget _switch(String emoji, String title, String sub, bool value, void Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        secondary: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(title, style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 17)),
        subtitle: Text(sub, style: const TextStyle(color: Colors.white60)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _voiceTile(String? name, String title, String locale) {
    final current = v.preferredVoice(ttsLang);
    final selected = current == name;
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppColors.blue : Colors.transparent, width: 1.5),
      ),
      child: ListTile(
        leading: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? AppColors.blue : Colors.white38),
        title: Text(title, textDirection: name == null ? null : TextDirection.ltr),
        subtitle: locale.isEmpty ? null : Text(locale, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white54)),
        onTap: () async {
          await v.setPreferredVoice(ttsLang, name);
          setState(() {});
          v.speakText(_sample, ttsLang);
        },
      ),
    );
  }
}
