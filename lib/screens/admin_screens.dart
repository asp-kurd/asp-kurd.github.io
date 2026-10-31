import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/backend.dart';
import '../ui.dart';
import 'account_screens.dart' show agoKu;

String _initial(dynamic n) {
  final s = (n as String? ?? '').trim();
  return s.isEmpty ? '?' : s.characters.first;
}

String _today() => DateTime.now().toIso8601String().substring(0, 10);
String _daysAgo(int n) => DateTime.now().subtract(Duration(days: n)).toIso8601String().substring(0, 10);

// ───────────────────────── 🔐 چوونا ژوور ─────────────────────────

class AdminEntry extends StatefulWidget {
  const AdminEntry({super.key});

  @override
  State<AdminEntry> createState() => _AdminEntryState();
}

class _AdminEntryState extends State<AdminEntry> {
  final email = TextEditingController(text: 'groupkurdish@gmail.com');
  final pass = TextEditingController();
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final b = Backend.instance;
    if (!b.enabled) {
      return const _Rtl(Scaffold(body: Center(child: Text('سێرڤەر هێشتا نەهاتییە گرێدان (Supabase)'))));
    }
    if (b.isAdmin) return const AdminDashboard();
    return _Rtl(Scaffold(
      appBar: AppBar(title: const Text('🛡️ ئەدمین')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        TextField(controller: email, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: pass, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: AppColors.red))),
        const SizedBox(height: 18),
        busy
            ? const Center(child: CircularProgressIndicator())
            : BigButton(
                label: 'چوونا ژوور',
                onPressed: () async {
                  setState(() => busy = true);
                  final e = await b.adminLogin(email.text, pass.text);
                  if (!mounted) return;
                  setState(() {
                    busy = false;
                    error = e;
                  });
                },
              ),
      ]),
    ));
  }
}

class _Rtl extends StatelessWidget {
  final Widget child;
  const _Rtl(this.child);
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: child);
}

// ───────────────────────── 📊 داشبۆرد ─────────────────────────

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final b = Backend.instance;
  List<Map<String, dynamic>> learners = [];
  Map<String, int> todaySec = {};
  Map<String, Set<String>> activeDays = {};
  bool loading = true;
  String? error;
  String q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      learners = await b.adminLearners();
      final act = await b.adminActivityAll(_daysAgo(6));
      todaySec = {};
      activeDays = {};
      for (final a in act) {
        final id = a['learner_id'] as String;
        final day = a['day'] as String;
        activeDays.putIfAbsent(id, () => {}).add(day);
        if (day == _today()) todaySec[id] = (a['seconds'] as num).toInt();
      }
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _Rtl(DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🛡️ رێڤەبەریا ASP'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await b.adminLogout();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: '👥 فێرخواز'),
            Tab(text: '📢 نامە'),
            Tab(text: '✏️ ناڤەرۆک'),
          ]),
        ),
        body: TabBarView(children: [
          _learnersTab(),
          const _BroadcastTab(),
          const ContentEditor(),
        ]),
      ),
    ));
  }

  Widget _learnersTab() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(error!)));
    final now = DateTime.now();
    final activeToday = learners.where((l) => todaySec.containsKey(l['id'])).length;
    final active7 = learners.where((l) => activeDays.containsKey(l['id'])).length;
    final newWeek = learners.where((l) => (DateTime.tryParse(l['created_at'] ?? '') ?? DateTime(2000)).isAfter(now.subtract(const Duration(days: 7)))).length;
    final shown = learners.where((l) => q.isEmpty || '${l['name']} ${l['city']}'.toLowerCase().contains(q.toLowerCase())).toList();

    Widget stat(String v, String label, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(v, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ),
        );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        Row(children: [
          stat('${learners.length}', 'هەمی', AppColors.blue),
          const SizedBox(width: 8),
          stat('$activeToday', 'ئەڤرۆ', AppColors.green),
          const SizedBox(width: 8),
          stat('$active7', '٧ رۆژ', AppColors.gold),
          const SizedBox(width: 8),
          stat('$newWeek', 'نوو', AppColors.orange),
        ]),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: InputDecoration(
            hintText: 'لێگەڕیان ب ناڤ یان باژێڕ…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        for (final l in shown) _learnerTile(l),
      ]),
    );
  }

  Widget _learnerTile(Map<String, dynamic> l) {
    final id = l['id'] as String;
    final seen = DateTime.tryParse(l['last_seen'] ?? '')?.toLocal();
    final online = seen != null && DateTime.now().difference(seen).inMinutes < 10;
    final min = ((todaySec[id] ?? 0) / 60).round();
    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LearnerDetail(learner: l))),
        leading: Stack(children: [
          CircleAvatar(
            backgroundColor: AppColors.blue,
            child: Text(_initial(l['name']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle, border: Border.all(color: AppColors.card, width: 2))),
            ),
        ]),
        title: Text('${l['name']}${switch (l['gender']) { 'm' => ' 👨', 'f' => ' 👩', _ => '' }}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${l['age'] ?? '–'} سال · ${l['city'] ?? ''}\n'
          '${seen == null ? '' : agoKu(seen)} · ⚡${l['xp'] ?? 0} · 🔥${l['streak'] ?? 0}${min > 0 ? ' · ئەڤرۆ $min خ' : ''}',
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'نامە',
          icon: const Icon(Icons.mail_rounded, color: AppColors.gold),
          onPressed: () => sendMessageDialog(context, learnerId: id, name: '${l['name']}'),
        ),
      ),
    );
  }
}

Future<void> sendMessageDialog(BuildContext context, {String? learnerId, required String name}) async {
  final title = TextEditingController(text: learnerId == null ? '📢 ' : 'سلاڤ $name! ');
  final body = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _Rtl(AlertDialog(
      title: Text(learnerId == null ? '📢 نامە بۆ هەمییان' : '✉️ نامە بۆ $name'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'سەرناڤ')),
        const SizedBox(height: 10),
        TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'نامە', border: OutlineInputBorder())),
        const SizedBox(height: 6),
        const Text('دێ د ئەپی دا و وەکی ئاگەهداری (ئەگەر ڤەکری بیت) گەهیت.', style: TextStyle(fontSize: 12, color: Colors.white54)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بەتالکرن')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('فرێکرن')),
      ],
    )),
  );
  if (ok != true || body.text.trim().isEmpty) return;
  final err = await Backend.instance.sendMessage(learnerId: learnerId, title: title.text.trim(), body: body.text.trim());
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err == null ? '✅ هاتە فرێکرن' : '❌ $err')));
  }
}

// ───────────────────────── 👤 هویرکاریێن فێرخوازی ─────────────────────────

class LearnerDetail extends StatefulWidget {
  final Map<String, dynamic> learner;
  const LearnerDetail({super.key, required this.learner});

  @override
  State<LearnerDetail> createState() => _LearnerDetailState();
}

class _LearnerDetailState extends State<LearnerDetail> {
  final b = Backend.instance;
  List<Map<String, dynamic>> act = [], exams = [], msgs = [];
  bool loading = true;

  String get id => widget.learner['id'] as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      act = await b.adminActivity(id);
      exams = await b.adminExams(id);
      msgs = await b.adminMessages(id);
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.learner;
    final created = DateTime.tryParse(l['created_at'] ?? '')?.toLocal();
    final byDay = {for (final a in act) a['day'] as String: a};
    final totalMin = act.fold<int>(0, (s, a) => s + ((a['seconds'] as num?) ?? 0).toInt()) ~/ 60;
    final days = [for (var k = 13; k >= 0; k--) _daysAgo(k)];
    final maxSec = days.map((d) => ((byDay[d]?['seconds'] as num?) ?? 0).toInt()).fold<int>(60, (a, b) => a > b ? a : b);

    return _Rtl(Scaffold(
      appBar: AppBar(title: Text('${l['name']}')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.mail_rounded),
        label: const Text('نامە'),
        onPressed: () async {
          await sendMessageDialog(context, learnerId: id, name: '${l['name']}');
          _load();
        },
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
              _info('👤', 'ناڤ', '${l['name']}'),
              _info('🎂', 'تەمەن', '${l['age'] ?? '–'}'),
              _info('⚧', 'ڕەگەز', switch (l['gender']) { 'm' => '👨 نێر', 'f' => '👩 مێ', _ => '–' }),
              _info('📍', 'جه', '${l['city'] ?? '–'}'),
              _info('🗓️', 'دەستپێک', created == null ? '–' : '${created.year}/${created.month}/${created.day}'),
              _info('👀', 'دویماهیک جار', DateTime.tryParse(l['last_seen'] ?? '') == null ? '–' : agoKu(DateTime.parse(l['last_seen']).toLocal())),
              _info('⚡', 'XP', '${l['xp'] ?? 0}'),
              _info('🔥', 'Streak', '${l['streak'] ?? 0} رۆژ'),
              _info('✅', 'قۆناغێن تەمامکری', '${l['completed_units'] ?? 0}'),
              _info('⏱️', 'دەمێ خواندنێ (٣٠ رۆژ)', '$totalMin خولەک'),
              _info('🔔', 'ئاگەهداری', l['push_sub'] == null ? 'نە ڤەکرییە' : 'ڤەکرییە ✅'),
              const SizedBox(height: 16),
              const Text('📊 خولەکێن خواندنێ (١٤ رۆژ)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final d in days)
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 4 + 96 * (((byDay[d]?['seconds'] as num?) ?? 0) / maxSec),
                            decoration: BoxDecoration(
                              color: byDay.containsKey(d) ? AppColors.green : Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(d.substring(8), style: const TextStyle(fontSize: 9, color: Colors.white54)),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              const Text('📝 ئەزموون', style: TextStyle(fontWeight: FontWeight.bold)),
              if (exams.isEmpty) const Text('هێشتا چ ئەزموون نەکرینە', style: TextStyle(color: Colors.white54)),
              for (final e in exams)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.assignment_turned_in_rounded),
                  title: Text('${e['exam_id']}'),
                  trailing: Text('${e['score']}/${e['total']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 12),
              const Text('✉️ نامەیێن فرێکری', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final m in msgs)
                ListTile(
                  dense: true,
                  title: Text('${m['title']}'),
                  subtitle: Text('${m['body']}'),
                  trailing: Text(m['read_at'] != null ? '👁️' : '•'),
                ),
            ]),
    ));
  }

  Widget _info(String e, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(e, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(k, style: const TextStyle(color: Colors.white60)),
          const Spacer(),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}

// ───────────────────────── 📢 نامە بۆ هەمییان ─────────────────────────

class _BroadcastTab extends StatefulWidget {
  const _BroadcastTab();

  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  List<Map<String, dynamic>> list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      list = await Backend.instance.adminMessages(null);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      BigButton(
        label: 'نامەیەکا نوو بۆ هەمی فێرخوازان',
        icon: Icons.campaign_rounded,
        color: AppColors.gold,
        onPressed: () async {
          await sendMessageDialog(context, name: 'هەمی');
          _load();
        },
      ),
      const SizedBox(height: 16),
      for (final m in list)
        Card(
          color: AppColors.card,
          child: ListTile(
            title: Text('${m['title']}'),
            subtitle: Text('${m['body']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
              onPressed: () async {
                await Backend.instance.deleteMessage((m['id'] as num).toInt());
                _load();
              },
            ),
          ),
        ),
    ]);
  }
}

// ───────────────────────── ✏️ گوهۆڕینا ناڤەرۆکێ ─────────────────────────

/// ئەدمین دشێت هەر پەیڤەکێ بگوهۆڕیت، زێدە بکەت یان ژێببەت. پاشەکەفتکرن ل سەر سێرڤەری،
/// و هەمی فێرخواز ل جارا بهێت ناڤەرۆکا نوو دبینن.
class ContentEditor extends StatefulWidget {
  const ContentEditor({super.key});

  @override
  State<ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<ContentEditor> {
  Map<String, dynamic>? data;
  bool dirty = false, saving = false, isOverride = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final o = await Backend.instance.contentOverride('curriculum');
    isOverride = o != null;
    final raw = o ?? await rootBundle.loadString('assets/curriculum.json');
    if (mounted) setState(() => data = jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final err = await Backend.instance.saveContent('curriculum', data!);
    if (!mounted) return;
    setState(() {
      saving = false;
      if (err == null) {
        dirty = false;
        isOverride = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err == null ? '✅ هاتە پاشەکەفتکرن. فێرخواز ل جارا بهێت دێ بینن.' : '❌ $err')));
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final units = (d['units'] as List).cast<Map<String, dynamic>>();
    return Column(children: [
      Container(
        color: AppColors.card,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(
            child: Text(isOverride ? '✏️ ناڤەرۆکا گوهۆڕی یا ب کار دهێت' : '📦 ناڤەرۆکا ئەسلی',
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ),
          if (isOverride)
            TextButton(
              onPressed: () async {
                await Backend.instance.resetContent('curriculum');
                await _load();
              },
              child: const Text('زڤڕاندن بۆ ئەسلی'),
            ),
          FilledButton.icon(
            onPressed: dirty && !saving ? _save : null,
            icon: saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            label: const Text('پاشەکەفت'),
          ),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(10), children: [
          for (final u in units)
            Card(
              color: AppColors.card,
              child: ExpansionTile(
                shape: const Border(),
                title: Text('${u['titleKu']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${(u['concepts'] as List).length} پەیڤ · ${u['titleDe']}', style: const TextStyle(fontSize: 12)),
                children: [
                  ListTile(
                    leading: const Icon(Icons.title_rounded),
                    title: const Text('گوهۆڕینا ناڤێ قۆناغێ'),
                    onTap: () => _editFields(u, const ['titleKu', 'titleDe', 'titleEn']),
                  ),
                  for (final c in (u['concepts'] as List).cast<Map<String, dynamic>>())
                    ListTile(
                      dense: true,
                      leading: Text('${c['emoji'] ?? ''}', style: const TextStyle(fontSize: 24)),
                      title: Text('${c['de']}', textDirection: TextDirection.ltr),
                      subtitle: Text('${c['ku']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.red),
                        onPressed: () => setState(() {
                          (u['concepts'] as List).remove(c);
                          dirty = true;
                        }),
                      ),
                      onTap: () => _editFields(c, const ['de', 'deHint', 'ku', 'kuLat', 'en', 'enHint', 'emoji']),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('پەیڤەکا نوو زێدە بکە'),
                    onPressed: () async {
                      final c = <String, dynamic>{
                        'id': 'x${DateTime.now().millisecondsSinceEpoch}',
                        'de': '', 'deHint': '', 'ku': '', 'kuLat': '', 'en': '', 'enHint': '', 'emoji': '',
                      };
                      final ok = await _editFields(c, const ['de', 'deHint', 'ku', 'kuLat', 'en', 'enHint', 'emoji']);
                      if (ok && (c['de'] as String).isNotEmpty) {
                        setState(() {
                          (u['concepts'] as List).add(c);
                          dirty = true;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
        ]),
      ),
    ]);
  }

  static const _labels = {
    'titleKu': 'ناڤ (بادینی)', 'titleDe': 'ناڤ (ئەلمانی)', 'titleEn': 'ناڤ (ئینگلیزی)',
    'de': 'ئەلمانی', 'deHint': 'خواندن / تێبینی', 'ku': 'بادینی', 'kuLat': 'بادینی (لاتینی)',
    'en': 'ئینگلیزی', 'enHint': 'خواندنا ئینگلیزی', 'emoji': 'وێنە (ئیمۆجی)',
  };

  Future<bool> _editFields(Map<String, dynamic> m, List<String> keys) async {
    final ctrls = {for (final k in keys) k: TextEditingController(text: '${m[k] ?? ''}')};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _Rtl(AlertDialog(
        title: const Text('✏️ گوهۆڕین'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final k in keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: ctrls[k],
                  textDirection: k == 'ku' || k == 'titleKu' || k.endsWith('Hint') ? TextDirection.rtl : TextDirection.ltr,
                  decoration: InputDecoration(labelText: _labels[k] ?? k, border: const OutlineInputBorder()),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بەتالکرن')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('باشە')),
        ],
      )),
    );
    if (ok == true) {
      setState(() {
        for (final k in keys) {
          m[k] = ctrls[k]!.text.trim();
        }
        dirty = true;
      });
      return true;
    }
    return false;
  }
}
