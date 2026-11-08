import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models.dart';
import '../../services/backend.dart';
import '../../services/progress_service.dart';
import '../../services/speech_stub.dart' if (dart.library.js_interop) '../../services/speech_web.dart';
import '../../services/voice_service.dart';
import '../../ui.dart';
import '../widgets/mascot.dart';

/// 🎓 Goethe-Zertifikat A1 (Start Deutsch 1) — Modelltest
/// Hören · Lesen · Schreiben · Sprechen، هەر پشکەک ب دەمژمێر، نمرە ژ ٦٠ (دەرچوون: ٣٦ = ٦٠٪).
class GoetheMockScreen extends StatefulWidget {
  const GoetheMockScreen({super.key});
  @override
  State<GoetheMockScreen> createState() => _GoetheMockScreenState();
}

String _ku(Object n) => '$n'.split('').map((d) => '0123456789'.contains(d) ? '٠١٢٣٤٥٦٧٨٩'['0123456789'.indexOf(d)] : d).join();

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[.,!?;:„“"«»()]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class _Flat {
  final int part, section;
  final Map<String, dynamic> item;
  _Flat(this.part, this.section, this.item);
}

class _GoetheMockScreenState extends State<GoetheMockScreen> {
  final voice = VoiceService.instance;
  Map<String, dynamic>? data;
  // -1 = دەستپێک، 0..3 = پشک، 4 = ئەنجام
  int part = -1;
  bool partIntro = true;
  int pos = 0; // ئێک ب ئێک د ناڤ پشکێ دا
  List<_Flat> items = [];
  final Map<_Flat, dynamic> answers = {};
  final Map<_Flat, double> scores = {}; // بۆ نڤیسین و ئاخفتنێ
  Timer? _timer;
  int secondsLeft = 0;
  final Map<_Flat, int> plays = {};
  bool playing = false;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/goethe.json').then((s) {
      if (mounted) setState(() => data = jsonDecode(s) as Map<String, dynamic>);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    voice.stopPlayback();
    super.dispose();
  }

  List get parts => data!['parts'] as List;
  Map<String, dynamic> get cp => parts[part] as Map<String, dynamic>;

  void _startPart(int k) {
    _timer?.cancel();
    voice.stopPlayback();
    setState(() {
      part = k;
      partIntro = true;
      pos = 0;
      items = [
        for (var s = 0; s < (cp['sections'] as List).length; s++)
          for (final it in (cp['sections'][s]['items'] as List)) _Flat(k, s, it as Map<String, dynamic>),
      ];
    });
  }

  void _beginTimer() {
    secondsLeft = (cp['minutes'] as int) * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => secondsLeft--);
      if (secondsLeft <= 0) {
        _timer?.cancel();
        _endPart();
      }
    });
    setState(() => partIntro = false);
    _autoPlay();
  }

  void _endPart() {
    _timer?.cancel();
    voice.stopPlayback();
    if (part + 1 < parts.length) {
      _startPart(part + 1);
    } else {
      _finish();
    }
  }

  _Flat get cur => items[pos];

  void _next() {
    voice.stopPlayback();
    if (pos + 1 < items.length) {
      setState(() => pos++);
      _autoPlay();
    } else {
      _endPart();
    }
  }

  // ───────── 🎧 دەنگ ─────────
  int _repeat(_Flat f) => (cp['sections'][f.section]['repeat'] as int?) ?? 1;

  void _autoPlay() {
    final f = cur;
    if (f.item['audio'] != null && (plays[f] ?? 0) == 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && cur == f) _play(f);
      });
    }
  }

  Future<void> _play(_Flat f) async {
    if (playing || (plays[f] ?? 0) >= _repeat(f)) return;
    setState(() {
      playing = true;
      plays[f] = (plays[f] ?? 0) + 1;
    });
    for (final ln in (f.item['audio'] as List)) {
      if (!mounted || cur != f) break;
      await voice.speakText(ln['t'] as String, AppLanguage.german, gender: ln['g'] as String);
      await Future.delayed(const Duration(milliseconds: 300));
      while (mounted && voice.speaking.value) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await Future.delayed(const Duration(milliseconds: 450));
    }
    if (mounted) setState(() => playing = false);
  }

  // ───────── نمرە ─────────
  double _itemScore(_Flat f) {
    final it = f.item;
    final a = answers[f];
    switch (it['t']) {
      case 'mc':
        return a == it['answer'] ? 1 : 0;
      case 'rf':
        return a == it['answer'] ? 1 : 0;
      case 'ab':
        return a == it['answer'] ? 1 : 0;
      case 'form':
        final m = (a as Map<int, String>?) ?? {};
        var p = 0.0;
        final fields = it['fields'] as List;
        for (var k = 0; k < fields.length; k++) {
          final ok = (fields[k]['answer'] as List).any((x) => _norm(x as String) == _norm(m[k] ?? ''));
          if (ok) p++;
        }
        return p; // ژ ٥
      case 'write':
        final txt = _norm((a as String?) ?? '');
        final words = txt.isEmpty ? 0 : txt.split(' ').length;
        var p = 0.0;
        for (final pt in it['points'] as List) {
          if ((pt['kw'] as List).any((k) => txt.contains(_norm(k as String)))) p += 2.5;
        }
        if (words >= 20) p += 1.5;
        if (words >= 30) p += 1;
        return p.clamp(0, 10); // ژ ١٠
      default:
        return scores[f] ?? 0; // ئاخفتن
    }
  }

  Map<String, double> get _partPoints {
    final out = <String, double>{};
    for (var k = 0; k < parts.length; k++) {
      final id = parts[k]['id'] as String;
      final all = [
        for (var s = 0; s < (parts[k]['sections'] as List).length; s++)
          for (final it in (parts[k]['sections'][s]['items'] as List)) answers.keys.followedBy(scores.keys).firstWhere(
                (f) => identical(f.item, it),
                orElse: () => _Flat(k, s, it as Map<String, dynamic>),
              ),
      ];
      out[id] = all.fold<double>(0, (a, f) => a + _itemScore(f)).clamp(0, (parts[k]['points'] as int).toDouble());
    }
    return out;
  }

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() => part = parts.length);
    final pts = _partPoints.values.fold<double>(0, (a, b) => a + b);
    final pct = (pts * 100 / 60).round();
    await ProgressService.instance.saveExam('goethe', pct);
    Backend.instance.examResult('goethe', pts.round(), 60);
    await ProgressService.instance.earn((pts / 2).round());
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(part >= 0 && part < (data == null ? 0 : parts.length) ? '🎓 ${cp['title']}' : '🎓 Goethe A1 — Modelltest'),
          actions: [
            if (part >= 0 && data != null && part < parts.length && !partIntro)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text('⏱ ${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: secondsLeft < 120 ? AppColors.red : AppColors.fg)),
                ),
              ),
          ],
          bottom: part >= 0 && data != null && part < parts.length && !partIntro
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(6),
                  child: LinearProgressIndicator(value: (pos + 1) / items.length, minHeight: 6, backgroundColor: AppColors.card),
                )
              : null,
        ),
        body: SafeArea(
          child: data == null
              ? const Center(child: CircularProgressIndicator())
              : (part < 0 ? _intro() : (part >= parts.length ? _result() : (partIntro ? _partIntro() : _itemView()))),
        ),
      ),
    );
  }

  Widget _intro() => ListView(padding: const EdgeInsets.all(20), children: [
        MascotSays(mood: MascotMood.ask, height: 120, text: 'ئەڤە ئەزموونەکا وەکی Goethe A1 یا ڕاستییە. بەرهەڤی؟ 💪'),
        const SizedBox(height: 14),
        for (final p in parts)
          Card(
            color: AppColors.card,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              title: Text('${p['ku']} · ${p['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${_ku(p['minutes'])} خولەک · ${_ku(p['points'])} خال'),
            ),
          ),
        const SizedBox(height: 6),
        Text('🏁 کۆی گشتی ٦٠ خالە. بۆ دەرچوونێ ٣٦ خال (٦٠٪) پێدڤینە. دەمێ هەر پشکەکێ ب دوماهی بهێت، پشکا دی دەستپێدکەت.',
            style: TextStyle(color: AppColors.fg70, height: 1.5)),
        if (ProgressService.instance.examBest('goethe') != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('باشترین ئەنجاما تە: ${_ku(ProgressService.instance.examBest('goethe')!)}٪',
                style: TextStyle(color: AppColors.goldText, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 18),
        BigButton(label: 'دەستپێکرن', color: AppColors.red, onPressed: () => _startPart(0)),
      ]);

  Widget _partIntro() => ListView(padding: const EdgeInsets.all(20), children: [
        Text('${cp['ku']} — ${cp['title']}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('⏱ ${_ku(cp['minutes'])} خولەک · ${_ku(items.length)} پرسیار', style: TextStyle(color: AppColors.fg60)),
        const SizedBox(height: 14),
        for (final s in cp['sections'] as List)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
            child: Text('${s['title']}: ${s['ku']}', style: const TextStyle(height: 1.5)),
          ),
        const SizedBox(height: 14),
        BigButton(label: 'دەستپێبکە ⏱', onPressed: _beginTimer),
      ]);

  Widget _itemView() {
    final f = cur;
    final it = f.item;
    final sec = cp['sections'][f.section] as Map<String, dynamic>;
    final ready = switch (it['t']) {
      'mc' || 'rf' || 'ab' => answers[f] != null,
      _ => true,
    };
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Text('${sec['title']} · ${sec['ku']}', style: TextStyle(color: AppColors.fg60, fontSize: 13)),
          const SizedBox(height: 10),
          if (it['audio'] != null) _audioBtn(f),
          if (it['text'] != null) _textCard(it['text'] as String),
          ..._body(f),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: BigButton(
          label: pos + 1 < items.length ? 'پرسیارا دی ➜' : 'ب دوماهی ئینانا پشکێ',
          onPressed: ready ? _next : null,
        ),
      ),
    ]);
  }

  Widget _audioBtn(_Flat f) {
    final left = _repeat(f) - (plays[f] ?? 0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.blue, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
          onPressed: playing || left <= 0 ? null : () => _play(f),
          icon: Icon(playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded),
          label: Text(playing ? 'گوهداری بکە…' : (left > 0 ? 'گوهداری (${_ku(left)} جار ماینە)' : 'تە گوهداری کر ✔')),
        ),
      ),
    );
  }

  Widget _textCard(String t) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fg24),
        ),
        child: Text(t, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 17, height: 1.5)),
      );

  Widget _q(String q, String ku) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(q, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          if (ku.isNotEmpty) Text(ku, style: TextStyle(color: AppColors.fg54, fontSize: 13)),
        ]),
      );

  Widget _choice(_Flat f, Object value, String label, {String? sub}) {
    final sel = answers[f] == value;
    return GestureDetector(
      onTap: () => setState(() => answers[f] = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? AppColors.blue.withValues(alpha: 0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? AppColors.blue : AppColors.fg24, width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub, textDirection: TextDirection.ltr, style: TextStyle(color: AppColors.fg70)),
          ],
        ]),
      ),
    );
  }

  List<Widget> _body(_Flat f) {
    final it = f.item;
    switch (it['t']) {
      case 'mc':
        final opts = it['options'] as List;
        return [
          _q(it['q'] as String, (it['ku'] ?? '') as String),
          for (var k = 0; k < opts.length; k++) _choice(f, k, '${'abc'[k]})  ${opts[k]}'),
        ];
      case 'rf':
        return [
          _q(it['q'] as String, (it['ku'] ?? '') as String),
          Row(textDirection: TextDirection.ltr, children: [
            Expanded(child: _choice(f, true, '✅ Richtig')),
            const SizedBox(width: 10),
            Expanded(child: _choice(f, false, '❌ Falsch')),
          ]),
        ];
      case 'ab':
        return [
          _q(it['q'] as String, (it['ku'] ?? '') as String),
          _choice(f, 'a', 'a', sub: it['a'] as String),
          _choice(f, 'b', 'b', sub: it['b'] as String),
        ];
      case 'form':
        return [_FormTask(item: it, onChanged: (m) => answers[f] = m, initial: (answers[f] as Map<int, String>?) ?? {})];
      case 'write':
        return [_WriteTask(item: it, onChanged: (t) => answers[f] = t, initial: (answers[f] as String?) ?? '')];
      default:
        return [_SpeakTask(item: it, onScore: (s) => scores[f] = s)];
    }
  }

  Widget _result() {
    final pp = _partPoints;
    final total = pp.values.fold<double>(0, (a, b) => a + b);
    final passed = total >= 36;
    return ListView(padding: const EdgeInsets.all(20), children: [
      MascotView(char: MascotChar.forUser(), mood: passed ? MascotMood.happy : MascotMood.think, height: 170),
      const SizedBox(height: 10),
      Text(passed ? '🎉 تو دەرچووی!' : '💪 هێشتا نە — دیسا راهێنان بکە', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: passed ? AppColors.green : AppColors.red)),
      Text('${_ku(total.round())} / ٦٠ خال · ${_ku((total * 100 / 60).round())}٪', textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      for (final p in parts)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Text('${p['ku']} · ${p['title']}', style: const TextStyle(fontWeight: FontWeight.bold))),
            Text('${_ku((pp[p['id']] ?? 0).toStringAsFixed(1).replaceAll('.0', ''))} / ${_ku(p['points'])}',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.goldText)),
          ]),
        ),
      const SizedBox(height: 10),
      Text('💡 خالێن نڤیسین و ئاخفتنێ ب نێزیکی ب ئەپی دهێنە حسابکرن، ل ئەزموونا ڕاستی مامۆستا نمرێ ددەت.',
          style: TextStyle(color: AppColors.fg60, fontSize: 13)),
      const SizedBox(height: 16),
      ExpansionTile(
        title: const Text('🔍 بەرسڤێن دروست ببینە', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [for (final w in _review()) w],
      ),
      const SizedBox(height: 16),
      BigButton(label: 'دیسا ئەزموونێ بکە 🔁', color: AppColors.red, onPressed: () {
        answers.clear();
        scores.clear();
        plays.clear();
        setState(() => part = -1);
      }),
    ]);
  }

  List<Widget> _review() {
    final out = <Widget>[];
    for (var k = 0; k < 2; k++) {
      for (var s = 0; s < (parts[k]['sections'] as List).length; s++) {
        for (final it in parts[k]['sections'][s]['items'] as List) {
          final f = answers.keys.firstWhere((x) => identical(x.item, it), orElse: () => _Flat(k, s, it as Map<String, dynamic>));
          final ok = _itemScore(f) >= 1;
          final right = switch (it['t']) {
            'mc' => (it['options'] as List)[it['answer'] as int],
            'rf' => it['answer'] == true ? 'Richtig' : 'Falsch',
            _ => it['answer'],
          };
          out.add(ListTile(
            dense: true,
            leading: Text(ok ? '✅' : '❌'),
            title: Text(it['q'] as String, textDirection: TextDirection.ltr),
            subtitle: Text('دروست: $right', style: const TextStyle(color: AppColors.green)),
          ));
        }
      }
    }
    return out;
  }
}

// ───────── ✍️ Teil 1: فۆرم ─────────
class _FormTask extends StatefulWidget {
  final Map<String, dynamic> item;
  final Map<int, String> initial;
  final void Function(Map<int, String>) onChanged;
  const _FormTask({required this.item, required this.onChanged, required this.initial});
  @override
  State<_FormTask> createState() => _FormTaskState();
}

class _FormTaskState extends State<_FormTask> {
  late final Map<int, String> m = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final fields = widget.item['fields'] as List;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.item['ku'] as String, style: TextStyle(color: AppColors.fg60)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.cardAlt, borderRadius: BorderRadius.circular(14)),
        child: Text(widget.item['text'] as String, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 16, height: 1.5)),
      ),
      const SizedBox(height: 14),
      const Text('Anmeldung – Deutschkurs', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      for (var k = 0; k < fields.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            initialValue: m[k],
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: '${k + 1}. ${fields[k]['label']}',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.card,
            ),
            onChanged: (v) {
              m[k] = v;
              widget.onChanged(m);
            },
          ),
        ),
    ]);
  }
}

// ───────── ✍️ Teil 2: ئیمەیل ─────────
class _WriteTask extends StatefulWidget {
  final Map<String, dynamic> item;
  final String initial;
  final void Function(String) onChanged;
  const _WriteTask({required this.item, required this.onChanged, required this.initial});
  @override
  State<_WriteTask> createState() => _WriteTaskState();
}

class _WriteTaskState extends State<_WriteTask> {
  late final ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = ctrl.text.trim().isEmpty ? 0 : ctrl.text.trim().split(RegExp(r'\s+')).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.item['task'] as String, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.4)),
      const SizedBox(height: 4),
      Text(widget.item['ku'] as String, style: TextStyle(color: AppColors.fg60)),
      const SizedBox(height: 8),
      for (final p in widget.item['points'] as List)
        Text('• ${p['de']}  —  ${p['ku']}', style: const TextStyle(height: 1.6)),
      const SizedBox(height: 10),
      TextField(
        controller: ctrl,
        maxLines: 8,
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontSize: 17),
        decoration: InputDecoration(
          hintText: 'Lieber Tim, …',
          hintTextDirection: TextDirection.ltr,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: AppColors.card,
        ),
        onChanged: (v) {
          setState(() {});
          widget.onChanged(v);
        },
      ),
      const SizedBox(height: 6),
      Text('${_ku(words)} پەیڤ', textAlign: TextAlign.end, style: TextStyle(color: words >= 30 ? AppColors.green : AppColors.fg54)),
    ]);
  }
}

// ───────── 🗣️ ئاخفتن ─────────
class _SpeakTask extends StatefulWidget {
  final Map<String, dynamic> item;
  final void Function(double) onScore;
  const _SpeakTask({required this.item, required this.onScore});
  @override
  State<_SpeakTask> createState() => _SpeakTaskState();
}

class _SpeakTaskState extends State<_SpeakTask> {
  final _l = SpeechListener();
  int card = 0;
  bool listening = false;
  final Map<int, String> heard = {};
  final Map<int, bool> ok = {};
  bool? self; // ئەگەر ناسینا دەنگی نەبیت: هەلسەنگاندنا خۆ

  Map<String, dynamic> get it => widget.item;
  String get t => it['t'] as String;
  List get cards => it['cards'] as List;

  @override
  void dispose() {
    _l.stop();
    super.dispose();
  }

  bool _judge(int k, String h) {
    final n = _norm(h);
    if (t == 'speak1') {
      // هەر خالەک کو هاتییە گۆتن
      return true;
    }
    if (t == 'speak2') {
      final w = _norm(cards[k]['w'] as String);
      return n.contains(w) && n.split(' ').length >= 3;
    }
    final kws = (cards[k]['kw'] as List).map((e) => _norm(e as String));
    final polite = ['bitte', 'koennen', 'koennten', 'kannst', 'haben sie', 'hast du', 'gib', 'geben sie'].any(n.contains);
    return kws.any(n.contains) && polite;
  }

  void _score() {
    double s;
    if (t == 'speak1') {
      final all = _norm(heard.values.join(' '));
      final groups = (it['kw'] as List).where((g) => (g as List).any((w) => all.contains(_norm(w as String)))).length;
      s = 3 * groups / (it['kw'] as List).length;
    } else {
      s = 6 * ok.values.where((v) => v).length / cards.length;
    }
    widget.onScore(s);
  }

  Future<void> _listen(int k) async {
    if (listening) {
      _l.stop();
      return;
    }
    setState(() => listening = true);
    final r = await _l.listen('de-DE', max: Duration(seconds: t == 'speak1' ? 30 : 10));
    if (!mounted) return;
    final h = r.isEmpty ? '' : r.first;
    setState(() {
      listening = false;
      heard[k] = h;
      ok[k] = h.isNotEmpty && _judge(k, h);
    });
    _score();
  }

  @override
  Widget build(BuildContext context) {
    final supported = speechSupported;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(it['ku'] as String, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      if (t == 'speak1') ...[
        Wrap(spacing: 8, runSpacing: 8, textDirection: TextDirection.ltr, children: [
          for (final c in cards)
            Chip(label: Text(c as String, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: AppColors.card),
        ]),
        const SizedBox(height: 14),
        _mic(0),
        if ((heard[0] ?? '').isNotEmpty) _heard(heard[0]!, null),
        _example(it['example'] as String),
      ] else ...[
        if (t == 'speak2') Text('Thema: ${it['theme']}', textDirection: TextDirection.ltr, style: TextStyle(color: AppColors.goldText, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (var k = 0; k < cards.length; k++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ok[k] == null ? AppColors.fg24 : (ok[k]! ? AppColors.green : AppColors.red), width: 2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text(t == 'speak2' ? '🃏 ${cards[k]['w']}' : '${cards[k]['pic']}',
                    textDirection: TextDirection.ltr, style: TextStyle(fontSize: t == 'speak2' ? 20 : 40, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (supported) _mic(k, small: true),
              ]),
              if ((heard[k] ?? '').isNotEmpty) _heard(heard[k]!, ok[k]),
              if (ok[k] != null) _example(cards[k]['ex'] as String),
            ]),
          ),
      ],
      if (!supported)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            const Text('ئەڤ مۆبایلە ناسینا دەنگی نینە. ب دەنگێ بلند بێژە، پاشان خۆ هەلسەنگینە:'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => self = true);
                    widget.onScore(t == 'speak1' ? 3 : 6);
                  },
                  child: Text('✅ من گۆت', style: TextStyle(fontWeight: self == true ? FontWeight.w900 : null)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => self = false);
                    widget.onScore(0);
                  },
                  child: Text('❌ نەشیام', style: TextStyle(fontWeight: self == false ? FontWeight.w900 : null)),
                ),
              ),
            ]),
          ]),
        ),
    ]);
  }

  Widget _mic(int k, {bool small = false}) {
    if (!speechSupported) return const SizedBox.shrink();
    final active = listening;
    final size = small ? 52.0 : 84.0;
    return Center(
      child: GestureDetector(
        onTap: () => _listen(k),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: active ? AppColors.red : AppColors.blue, shape: BoxShape.circle),
          child: Icon(active ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }

  Widget _heard(String h, bool? good) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('${good == null ? '👂' : (good ? '✅' : '❌')} «$h»', textDirection: TextDirection.ltr,
            style: TextStyle(color: good == false ? AppColors.red : AppColors.fg70)),
      );

  Widget _example(String ex) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: InkWell(
          onTap: () => VoiceService.instance.speakText(ex, AppLanguage.german),
          child: Text('💡 نموونە: $ex 🔊', textDirection: TextDirection.ltr, style: TextStyle(color: AppColors.blue, fontSize: 14)),
        ),
      );
}
