import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/clone_service.dart';
import '../services/progress_service.dart';
import '../services/voice_service.dart';
import '../ui.dart';
import 'widgets/record_button.dart';

/// 🧬 کلۆنکرنا دەنگی: ب نموونەیەکا کورت ژ دەنگێ تە، هەمی وانە ب دەنگێ تە ب سێ زمانان.
class VoiceCloneScreen extends StatefulWidget {
  const VoiceCloneScreen({super.key});

  @override
  State<VoiceCloneScreen> createState() => _VoiceCloneScreenState();
}

class _VoiceCloneScreenState extends State<VoiceCloneScreen> {
  final voice = VoiceService.instance;
  final clone = CloneService.instance;
  AppLanguage get ui => ProgressService.instance.nativeLang;

  bool consent = false;
  late final urlCtrl = TextEditingController(text: clone.serverUrl);
  late final tokenCtrl = TextEditingController(text: clone.token);
  bool? serverOk;
  bool busy = false;
  bool cancel = false;
  int done = 0, total = 0;
  String current = '';

  @override
  void dispose() {
    cancel = true;
    urlCtrl.dispose();
    tokenCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _testServer() async {
    await clone.saveSettings(urlCtrl.text, tokenCtrl.text);
    final ok = await clone.ping();
    setState(() => serverOk = ok);
  }

  Future<void> _generate() async {
    if (!consent) {
      _snack(tr(ui, 'ئێکەم پشتڕاست بکە کو ئەڤە دەنگێ تەیە', 'Bitte zuerst bestätigen', 'Please confirm consent first'));
      return;
    }
    await clone.saveSettings(urlCtrl.text, tokenCtrl.text);
    setState(() {
      busy = true;
      cancel = false;
      current = tr(ui, 'فرێکرنا نموونەیێ...', 'Probe wird hochgeladen...', 'Uploading sample...');
    });
    try {
      await clone.uploadReferences();
      final failed = await clone.generateAll(
        isCancelled: () => cancel,
        onProgress: (d, t, label) {
          if (!mounted) return;
          setState(() {
            done = d;
            total = t;
            current = label;
          });
        },
      );
      if (mounted) {
        _snack(failed == 0
            ? tr(ui, '🎉 هەمی وانە ب دەنگێ تە نە!', '🎉 Alles in deiner Stimme!', '🎉 Everything is in your voice now!')
            : tr(ui, '$failed پەیڤ سەرنەکەفتن — دووبارە بکە', '$failed fehlgeschlagen', '$failed failed — try again'));
      }
    } catch (e) {
      if (mounted) _snack('❌ $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// هاوردەکرنا voice_pack.zip کو ژ Colab هاتیە داگرتن (Downloads)
  Future<void> _importPack() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    final path = res?.files.single.path;
    if (path == null) return;
    setState(() => busy = true);
    try {
      final n = await voice.importPack(path);
      if (!mounted) return;
      _snack(n > 0
          ? tr(ui, '🎉 $n دەنگ هاتنە هاوردەکرن!', '🎉 $n Stimmen importiert!', '🎉 Imported $n voices!')
          : tr(ui, '❌ د ڤێ zip دا چ دەنگ نەبوون', '❌ Keine Stimmen gefunden', '❌ No voices found in this zip'));
    } catch (e) {
      if (mounted) _snack('❌ $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myVoiceCount = AppLanguage.values.fold<int>(0, (s, l) => s + voice.countMyVoice(l, allConcepts));
    final totalSlots = allConcepts.length * AppLanguage.values.length;

    return Directionality(
      textDirection: ui.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(ui, '🧬 کلۆنکرنا دەنگێ من', '🧬 Stimme klonen', '🧬 Clone my voice'))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            Text(
              tr(ui,
                  'نموونەیەکا کورت (١٠–٢٠ چرکە) ژ دەنگێ خۆ تۆمار بکە. AI دێ هەمی پەیڤان ب دەنگێ تە ب بادینی، ئەلمانی و ئینگلیزی دروست کەت.',
                  'Nimm 10–20 Sekunden deiner Stimme auf. Die KI spricht dann alle Wörter in deiner Stimme – auf Badini, Deutsch und Englisch.',
                  'Record 10–20 seconds of your voice. AI will then speak every word in your voice — in Badini, German and English.'),
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 12),
            _progressCard(myVoiceCount, totalSlots),
            const SizedBox(height: 20),
            _sectionTitle(tr(ui, '١. نموونەیا دەنگی', '1. Stimmprobe', '1. Voice sample')),
            Text(
              tr(ui, '💡 ل جهەکێ بێدەنگ، مۆبایلێ ١٥ سم دوور بگرە، ب دەنگەکێ ئاسایی بخوینە.',
                  '💡 Ruhiger Ort, Handy 15 cm entfernt, natürlich sprechen.', '💡 Quiet room, phone ~15 cm away, speak naturally.'),
              style: const TextStyle(color: AppColors.blue, fontSize: 13),
            ),
            const SizedBox(height: 10),
            for (final lang in AppLanguage.values) _referenceCard(lang),
            CheckboxListTile(
              value: consent,
              onChanged: (v) => setState(() => consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(tr(ui, 'ئەڤە دەنگێ منە ب خۆ، و ئەز دەستووریێ ددەم کلۆن ببیت.',
                  'Das ist meine eigene Stimme und ich stimme dem Klonen zu.', 'This is my own voice and I consent to cloning it.')),
            ),
            const SizedBox(height: 16),
            _sectionTitle(tr(ui, '٢. دروستکرنا دەنگان', '2. Stimmen erzeugen', '2. Generate voices')),
            _pathA(),
            const SizedBox(height: 12),
            _pathB(),
            const SizedBox(height: 20),
            if (myVoiceCount > 0) _previewCard(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget _progressCard(int mine, int total) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Text('🎙️', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(ui, 'پەیڤێن ب دەنگێ تە', 'Wörter in deiner Stimme', 'Words in your voice')),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: total == 0 ? 0 : mine / total,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(AppColors.green),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Text('$mine/$total', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _referenceCard(AppLanguage lang) {
    final has = voice.hasReference(lang);
    final required = lang == AppLanguage.badini;
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: has ? AppColors.green : Colors.white12, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text('${lang.flag} ${lang.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(required ? tr(ui, '(پێدڤی)', '(Pflicht)', '(required)') : tr(ui, '(ئارەزوومەندانە)', '(optional)', '(optional)'),
                  style: TextStyle(color: required ? AppColors.orange : Colors.white38, fontSize: 12)),
              const Spacer(),
              if (has) const Icon(Icons.check_circle, color: AppColors.green),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
              child: Text(referenceScripts[lang]!,
                  textDirection: lang.direction, style: const TextStyle(fontSize: 17, height: 1.6)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (has)
                  IconButton(
                    tooltip: 'Play',
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.blue, size: 36),
                    onPressed: () => voice.playFile(voice.referencePath(lang)),
                  ),
                RecordButton(
                  size: 56,
                  toggle: true,
                  maxSeconds: 30,
                  hintText: tr(ui, 'کلیک بکە، بخوینە، دووبارە کلیک بکە', 'Tippen, lesen, erneut tippen', 'Tap, read, tap again'),
                  onStart: () => voice.startRecording(path: voice.referencePath(lang)),
                  onStop: () async {
                    final p = await voice.stopRecording();
                    if (p != null && mounted) setState(() {});
                  },
                ),
                if (has)
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.ios_share_rounded, color: Colors.white70),
                    onPressed: () => Share.shareXFiles([XFile(voice.referencePath(lang))],
                        text: 'ZimanPro voice sample (${lang.code})'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// رێکا A: Colab (بێ پارە، بێ سێرڤەر)
  Widget _pathA() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(ui, '🅰️ رێکا Colab (ب ساناهی)', '🅰️ Über Colab (einfach)', '🅰️ Colab route (easy)'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            tr(ui,
                '١. نموونەیێ ب 📤 پاشەکەفت بکە ل Files\n٢. ZimanPro_Voice_Lab.ipynb ل Google Colab ڤەکە و نموونەیێ بار بکە\n٣. voice_pack.zip دێ هێتە داگرتن\n٤. دوگمەیا خوارێ بکە و zip هەلبژێرە ✅',
                '1. Probe per 📤 in Dateien speichern\n2. ZimanPro_Voice_Lab.ipynb in Colab öffnen, Probe hochladen\n3. voice_pack.zip wird heruntergeladen\n4. Unten tippen und zip wählen ✅',
                '1. Save the sample to Files via 📤\n2. Open ZimanPro_Voice_Lab.ipynb in Colab, upload sample\n3. voice_pack.zip downloads\n4. Tap below and pick the zip ✅'),
            style: const TextStyle(color: Colors.white70, height: 1.6),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: BigButton(
              label: tr(ui, 'هاوردەکرنا voice_pack.zip', 'voice_pack.zip importieren', 'Import voice_pack.zip'),
              icon: Icons.file_open_rounded,
              color: const Color(0xFF8E2DE2),
              onPressed: busy ? null : _importPack,
            ),
          ),
        ]),
      );

  /// رێکا B: سێرڤەرێ زیندی (Colab + cloudflared یان کۆمپیوتەرەکێ ب GPU)
  Widget _pathB() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr(ui, '🅱️ راستەوخۆ ژ ئەپی (سێرڤەر)', '🅱️ Direkt aus der App (Server)', '🅱️ Directly from the app (server)'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          TextField(
            controller: urlCtrl,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Server URL', hintText: 'https://xxxx.trycloudflare.com', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: tokenCtrl,
            textDirection: TextDirection.ltr,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Token', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(
              onPressed: busy ? null : _testServer,
              icon: const Icon(Icons.wifi_tethering_rounded),
              label: Text(tr(ui, 'تاقیکرن', 'Testen', 'Test')),
            ),
            const SizedBox(width: 10),
            if (serverOk != null)
              Text(serverOk! ? '✅ Online' : '❌ Offline',
                  style: TextStyle(color: serverOk! ? AppColors.green : AppColors.red, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          if (busy) ...[
            LinearProgressIndicator(value: total == 0 ? null : done / total, minHeight: 10),
            const SizedBox(height: 6),
            Text('$done / $total   $current', maxLines: 1, overflow: TextOverflow.ellipsis),
            TextButton(onPressed: () => setState(() => cancel = true), child: Text(tr(ui, 'راوەستاندن', 'Stopp', 'Stop'))),
          ] else
            BigButton(
              label: tr(ui, 'هەمی وانە ب دەنگێ من دروست بکە', 'Alles in meiner Stimme erzeugen', 'Generate everything in my voice'),
              icon: Icons.auto_awesome_rounded,
              onPressed: voice.hasReference(AppLanguage.badini) ? _generate : null,
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await clone.deleteFromServer();
                    await voice.deleteAllCloned();
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.red),
            label: Text(tr(ui, 'ژێبرنا دەنگێ کلۆنکری', 'Geklonte Stimme löschen', 'Delete cloned voice'),
                style: const TextStyle(color: AppColors.red)),
          ),
        ]),
      );

  Widget _previewCard() {
    final c = allConcepts.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(tr(ui, '🎧 گوهێ خۆ بدە دەنگێ خۆ', '🎧 Hör dir deine Stimme an', '🎧 Hear yourself'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AppLanguage.values
              .where((l) => voice.inMyVoice(c, l))
              .map((l) => ActionChip(
                    avatar: Text(l.flag),
                    label: Text(c.text(l)),
                    onPressed: () => voice.speak(c, l),
                  ))
              .toList(),
        ),
      ]),
    );
  }
}
