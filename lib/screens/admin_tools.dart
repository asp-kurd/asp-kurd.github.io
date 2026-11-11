import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../data/tree.dart';
import '../models.dart';
import '../services/backend.dart';
import '../services/rewards_service.dart';
import '../ui.dart';

/// 🛡️ ئامرازێن ئەدمینی: دینار، خەلەتیێن فێرخوازی، بابەتێن لاواز، ئەزموونا دیاری، و دارا ب ناڤ

String _txt(WordConcept c, String lang) => lang == 'en' ? c.en : c.de;

List<LessonUnit> unitsFor(String lang) =>
    allUnitsRaw.where((u) => (u.only == null || u.only == lang) && !u.isAlphabet).toList();

Future<String?> sendTask(String? learnerId, String title, String text, Map<String, dynamic> task) =>
    Backend.instance.sendMessage(
        learnerId: learnerId, title: title, body: '${text.trim()}\n${AdminTask.encode(task)}'.trim());

void _snack(BuildContext context, String? err) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err == null ? '✅ هاتە فرێکرن' : '❌ $err')));
}

class _Rtl extends StatelessWidget {
  final Widget child;
  const _Rtl(this.child);
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: child);
}

// ───────────────────────── 🪙 دان / برینا دیناران ─────────────────────────

Future<void> dinarDialog(BuildContext context, {required String learnerId, required String name, int? balance}) async {
  final amount = TextEditingController(text: '20');
  final note = TextEditingController(text: 'دیاری ژ مامۆستای 🎁');
  var give = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => _Rtl(AlertDialog(
        title: Text('🪙 دینار بۆ $name${balance == null ? '' : ' (نوکە: $balance)'}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('➕ بدە')),
              ButtonSegment(value: false, label: Text('➖ ببە')),
            ],
            selected: {give},
            onSelectionChanged: (v) => set(() {
              give = v.first;
              note.text = give ? 'دیاری ژ مامۆستای 🎁' : 'دینار هاتنە برین';
            }),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [
            for (final v in [5, 10, 15, 20, 50, 100])
              ActionChip(label: Text('$v'), onPressed: () => set(() => amount.text = '$v')),
          ]),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ژمارا دیناران')),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'نامە (دێ بینیت)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بەتالکرن')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('فرێکرن')),
        ],
      )),
    ),
  );
  final n = int.tryParse(amount.text.trim()) ?? 0;
  if (ok != true || n <= 0) return;
  final v = give ? n : -n;
  final err = await sendTask(learnerId, note.text.trim().isEmpty ? '🪙 دینار' : note.text.trim(),
      give ? '+$n دینار 🪙' : '-$n دینار', {'t': 'dinar', 'n': v});
  if (context.mounted) _snack(context, err);
}

// ───────────────────────── 🎁 ئەزموونا دیاری ─────────────────────────

/// ئەزموونەک ژ قۆناغەکێ یان ژ پەیڤێن هەلبژارتی + خەلات (learnerId == null ➔ بۆ هەمییان)
Future<void> giftQuizDialog(BuildContext context,
    {String? learnerId, required String name, required String lang, List<String>? conceptIds}) async {
  final units = unitsFor(lang);
  LessonUnit? unit = conceptIds == null && units.isNotEmpty ? units.first : null;
  final reward = TextEditingController(text: '20');
  final note = TextEditingController(text: conceptIds == null ? 'ئەزموونەکا دیاری بۆ تە 🎁' : 'ئەڤە ئەو پەیڤن یێن تە خەلەت کرین — دووبارە بکە 💪');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => _Rtl(AlertDialog(
        title: Text('🎁 ئەزموون بۆ $name'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (conceptIds != null)
              Text('${conceptIds.length} پرسیار ژ خەلەتیێن وی/وێ', style: const TextStyle(fontWeight: FontWeight.bold))
            else
              DropdownButton<LessonUnit>(
                isExpanded: true,
                value: unit,
                items: [
                  for (final u in units)
                    DropdownMenuItem(value: u, child: Text(u.titleKu, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (u) => set(() => unit = u),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (final v in [5, 10, 15, 20, 30, 50])
                ActionChip(label: Text('$v 🪙'), onPressed: () => set(() => reward.text = '$v')),
            ]),
            TextField(controller: reward, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'خەلات (دینار) — ئەگەر ٦٠٪+')),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'نامە')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بەتالکرن')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('فرێکرن')),
        ],
      )),
    ),
  );
  if (ok != true) return;
  final ids = conceptIds ?? [for (final c in unit?.concepts ?? const <WordConcept>[]) c.id];
  if (ids.isEmpty) return;
  final r = int.tryParse(reward.text.trim()) ?? 0;
  final err = await sendTask(learnerId, '🎁 ئەزموونا دیاری', note.text, {'t': 'quiz', 'ids': ids, 'r': r, 'lang': lang});
  if (context.mounted) _snack(context, err);
}

// ───────────────────────── 📉 خەلەتی و بابەتێن لاواز ─────────────────────────

class LearnerInsights extends StatefulWidget {
  final String learnerId, name, lang;
  const LearnerInsights({super.key, required this.learnerId, required this.name, required this.lang});

  @override
  State<LearnerInsights> createState() => _LearnerInsightsState();
}

class _LearnerInsightsState extends State<LearnerInsights> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  final Set<String> picked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      data = await Backend.instance.adminProgress(widget.learnerId);
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  /// conceptId ➔ ژمارا خەلەتیان (ژ هەمی جووتێن زمانان)
  Map<String, int> get mistakes {
    final out = <String, int>{};
    for (final e in (data ?? const {}).entries) {
      if (!e.key.startsWith('mist_') || e.value is! List) continue;
      for (final x in e.value as List) {
        final p = '$x'.split(':');
        if (p.length == 2) out[p[0]] = (out[p[0]] ?? 0) + (int.tryParse(p[1]) ?? 0);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
    final dinar = (data?['dinar'] as num?)?.toInt();
    final freezes = (data?['freezes'] as num?)?.toInt() ?? 0;
    final mist = mistakes.entries.where((e) => e.value > 0 && conceptById(e.key) != null).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // بابەتێن لاواز: کۆما خەلەتیان بۆ هەر قۆناغەکێ
    final byUnit = <String, int>{};
    for (final e in mist) {
      final u = unitOfConcept(e.key);
      if (u != null) byUnit[u.id] = (byUnit[u.id] ?? 0) + e.value;
    }
    final weak = byUnit.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 🪙
      Card(
        color: AppColors.gold.withValues(alpha: 0.12),
        child: ListTile(
          leading: Image.asset('assets/img/fx/coin_s.webp', width: 36),
          title: Text(dinar == null ? 'دینار: —' : 'دینار: $dinar   🧊 $freezes'),
          subtitle: const Text('دیاری بدە یان دینار ببە'),
          trailing: FilledButton(
            onPressed: () => dinarDialog(context, learnerId: widget.learnerId, name: widget.name, balance: dinar),
            child: const Text('🪙 ±'),
          ),
        ),
      ),
      Card(
        child: ListTile(
          leading: Image.asset('assets/img/fx/gift.webp', width: 36),
          title: const Text('🎁 ئەزموونەکا دیاری فرێکە'),
          subtitle: const Text('قۆناغەکێ هەلبژێرە + خەلاتەک ئەگەر ٦٠٪+'),
          onTap: () => giftQuizDialog(context, learnerId: widget.learnerId, name: widget.name, lang: widget.lang),
        ),
      ),
      if (error != null || data == null)
        Card(
          color: AppColors.red.withValues(alpha: 0.12),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('⚠️ خەلەتیێن ڤی فێرخوازی ناهێنە خواندن.\n'
                'ئەگەر ئێکەم جارە: فایلا backend/admin_tools.sql د Supabase ➔ SQL Editor دا Run بکە (ئێک جار).\n'
                'یان هێشتا ئەڤی فێرخوازی پێشکەفتن نەپاراستییە.'),
          ),
        ),
      const SizedBox(height: 14),
      Text('📉 بابەتێن لاواز (پترین خەلەتی)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      if (weak.isEmpty) Text('چ خەلەتی نینن 👏', style: TextStyle(color: AppColors.fg54)),
      for (final w in weak.take(6))
        Builder(builder: (context) {
          final u = allUnitsRaw.firstWhere((x) => x.id == w.key);
          return Card(
            child: ListTile(
              title: Text(u.titleKu),
              subtitle: Text('${w.value} خەلەتی · ${u.titleDe}'),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  final err = await sendTask(widget.learnerId, '📌 دووبارە بخوینە', 'تو ل ڤی بابەتی گەلەک خەلەتی دکەی — جارەکا دی بخوینە 💪',
                      {'t': 'assign', 'unit': u.id, 'r': 10});
                  if (context.mounted) _snack(context, err);
                },
                child: const Text('📌 دووبارە'),
              ),
            ),
          );
        }),
      const SizedBox(height: 14),
      Row(children: [
        const Expanded(child: Text('❌ پەیڤێن خەلەت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        if (mist.isNotEmpty)
          TextButton(
            onPressed: () => setState(() {
              if (picked.length == mist.length) {
                picked.clear();
              } else {
                picked.addAll(mist.map((e) => e.key));
              }
            }),
            child: Text(picked.length == mist.length ? 'هیچ' : 'هەمی'),
          ),
      ]),
      for (final e in mist.take(40))
        CheckboxListTile(
          dense: true,
          value: picked.contains(e.key),
          onChanged: (v) => setState(() => v == true ? picked.add(e.key) : picked.remove(e.key)),
          title: Text(_txt(conceptById(e.key)!, widget.lang), textDirection: TextDirection.ltr, textAlign: TextAlign.right),
          subtitle: Text('${conceptById(e.key)!.ku} · ${e.value}×'),
        ),
      if (mist.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            onPressed: () {
              final ids = picked.isEmpty ? mist.take(10).map((e) => e.key).toList() : picked.toList();
              giftQuizDialog(context, learnerId: widget.learnerId, name: widget.name, lang: widget.lang, conceptIds: ids);
            },
            icon: const Icon(Icons.quiz_rounded),
            label: Text(picked.isEmpty ? '📝 ١٠ خەلەتیێن پترین ➔ ئەزموون' : '📝 ${picked.length} پەیڤ ➔ ئەزموون'),
          ),
        ),
    ]);
  }
}

// ───────────────────────── 🌳 گوهۆڕینا دارێ ─────────────────────────

class TreeEditor extends StatefulWidget {
  const TreeEditor({super.key});
  @override
  State<TreeEditor> createState() => _TreeEditorState();
}

class _TreeEditorState extends State<TreeEditor> {
  late List<List<TextEditingController>> rows;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _fill(treeStages);
    Backend.instance.contentOverride('tree').then((raw) {
      if (raw == null || !mounted) return;
      loadTree(raw);
      setState(() => _fill(treeStages));
    });
  }

  void _fill(List<TreeStage> list) {
    rows = [
      for (final t in list)
        [
          TextEditingController(text: t.emoji),
          TextEditingController(text: t.ku),
          TextEditingController(text: t.de),
          TextEditingController(text: t.en),
          TextEditingController(text: '${t.xp}'),
        ],
    ];
  }

  Future<void> _save() async {
    final list = [
      for (final r in rows)
        TreeStage(int.tryParse(r[4].text.trim()) ?? 0, r[0].text.trim().isEmpty ? '🌳' : r[0].text.trim(), r[1].text.trim(),
            r[2].text.trim().isEmpty ? r[1].text.trim() : r[2].text.trim(), r[3].text.trim().isEmpty ? r[1].text.trim() : r[3].text.trim()),
    ]..sort((a, b) => a.xp.compareTo(b.xp));
    if (list.length < 2 || list.first.xp != 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ دڤێت ٢+ قۆناغ هەبن و یا ئێکێ 0 XP بیت')));
      return;
    }
    setState(() => saving = true);
    final err = await Backend.instance.saveContent('tree', [for (final t in list) t.toJson()]);
    treeStages = list;
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err == null ? '✅ دار هاتە پاشەکەفتکرن — بۆ هەمییان' : '❌ $err')));
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String l) => InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder());
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
      const Text('🌳 قۆناغێن دارێ — ناڤ، ئیمۆجی و XP ب دلێ خۆ بگوهۆڕە', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      Text('هەر قۆناغەکا نوو کو فێرخواز دگەهیتێ، خەلاتا دیناران وەردگریت.', style: TextStyle(color: AppColors.fg54, fontSize: 12)),
      const SizedBox(height: 10),
      for (var i = 0; i < rows.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Row(children: [
                Text('قۆناغ ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                  onPressed: rows.length <= 2 ? null : () => setState(() => rows.removeAt(i)),
                ),
              ]),
              Row(children: [
                SizedBox(width: 64, child: TextField(controller: rows[i][0], textAlign: TextAlign.center, decoration: dec('ئیمۆجی'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: rows[i][1], decoration: dec('ناڤ (کوردی)'))),
                const SizedBox(width: 8),
                SizedBox(width: 84, child: TextField(controller: rows[i][4], keyboardType: TextInputType.number, decoration: dec('XP'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: rows[i][2], textDirection: TextDirection.ltr, decoration: dec('Deutsch'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: rows[i][3], textDirection: TextDirection.ltr, decoration: dec('English'))),
              ]),
            ]),
          ),
        ),
      OutlinedButton.icon(
        onPressed: () => setState(() {
          final lastXp = int.tryParse(rows.last[4].text) ?? 0;
          rows.add([
            TextEditingController(text: '🌳'),
            TextEditingController(text: 'قۆناغا نوو'),
            TextEditingController(),
            TextEditingController(),
            TextEditingController(text: '${lastXp + 1000}'),
          ]);
        }),
        icon: const Icon(Icons.add),
        label: const Text('قۆناغەکا نوو'),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: saving ? null : _save,
        icon: const Icon(Icons.save_rounded),
        label: const Text('پاشەکەفتکرن بۆ هەمییان'),
      ),
      TextButton(
        onPressed: () async {
          final err = await Backend.instance.resetContent('tree');
          treeStages = defaultTreeStages;
          setState(() => _fill(treeStages));
          if (context.mounted) _snack(context, err);
        },
        child: const Text('↩️ زڤڕاندنا ناڤێن ئەسلی'),
      ),
    ]);
  }
}
