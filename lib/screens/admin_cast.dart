import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/cast.dart';
import '../services/backend.dart';
import '../services/char_image.dart';
import '../ui.dart';
import 'widgets/mascot.dart';

// ───────────────────────── 👥 کاراکتەر (ئەدمین) ─────────────────────────

/// تابا «👥 کاراکتەر»: ناڤێن ناڤ رستان + کاراکتەرێن 3D + کاراکتەرێ نوو
class CastAdminTab extends StatefulWidget {
  /// بۆ تاقیکرنێ (demo): بێ بارکرن ژ سێرڤەری
  final bool offline;
  const CastAdminTab({super.key, this.offline = false});

  @override
  State<CastAdminTab> createState() => _CastAdminTabState();
}

class _CastAdminTabState extends State<CastAdminTab> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.offline) {
      try {
        await CastStore.refresh();
      } catch (_) {}
    }
    if (mounted) setState(() => loading = false);
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _editName(StoryName s) async {
    final l = TextEditingController(text: CastStore.latinOf(s));
    final k = TextEditingController(text: CastStore.kuOf(s));
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('✏️ ${s.ku} · ${s.latin}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('ناڤێ نوو دێ ل هەمی رستێن ئەپێ دیار بیت.', style: TextStyle(color: AppColors.fg60, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: l,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'ب لاتینی (بۆ ئەلمانی / ئینگلیزی)', hintText: 'Safin'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: k,
              decoration: const InputDecoration(labelText: 'ب کوردی', hintText: 'سەفین'),
            ),
            const SizedBox(height: 10),
            Text('🔊 ئەو رستێن ناڤ تێدا هاتییە گوهۆڕین، ب دەنگێ مۆبایلێ دهێنە خواندن هەتا دەنگ ژ نوی دهێنە دروستکرن.',
                style: TextStyle(color: AppColors.fg54, fontSize: 12)),
          ]),
          actions: [
            if (CastStore.names.containsKey(s.id))
              TextButton(onPressed: () => Navigator.pop(ctx, 'reset'), child: const Text('↩️ ناڤێ ئەسلی')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('نە')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('پاراستن')),
          ],
        ),
      ),
    );
    if (res == null) return;
    if (res == 'reset') {
      CastStore.names.remove(s.id);
    } else {
      final nl = l.text.trim(), nk = k.text.trim();
      if (nl == s.latin && nk == s.ku) {
        CastStore.names.remove(s.id);
      } else {
        CastStore.names[s.id] = {'l': nl == s.latin ? '' : nl, 'k': nk == s.ku ? '' : nk};
      }
    }
    final err = widget.offline ? null : await CastStore.save();
    if (!mounted) return;
    setState(() {});
    _toast(err == null ? '✅ هاتە پاراستن — پشتی ڤەکرنا ئەپێ ل هەمی رستان دیار دبیت' : '❌ $err');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final chars = MascotChar.everyone;
    return ValueListenableBuilder<int>(
      valueListenable: CastStore.changed,
      builder: (_, __, ___) => ListView(padding: const EdgeInsets.all(14), children: [
        _head('🦸 کاراکتەر', 'دەست ل کاراکتەرەکی بدە بۆ گوهۆڕینا ناڤی، وێنەیان یان ڤەشارتنێ.'),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: BigButton(
            label: 'کاراکتەرێ نوو',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CharEditScreen(offline: widget.offline))),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
          children: [for (final c in chars) _charTile(c)],
        ),
        const SizedBox(height: 22),
        _head('📝 ناڤێن ناڤ رستان', 'ئەڤ ناڤە د وانە، دیالۆگ و پرسیاران دا دهێن. ناڤەکی بگوهۆڕە ➔ ل هەمی رستان دگوهۆڕیت.'),
        const SizedBox(height: 8),
        for (final s in storyNames) _nameTile(s),
        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _head(String t, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(color: AppColors.fg60, fontSize: 13)),
      ]);

  Widget _nameTile(StoryName s) {
    final changed = CastStore.names.containsKey(s.id);
    final kind = switch (s.gender) { 'f' => '👩', 'm' => '👨', _ => '🏷️' };
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14), side: BorderSide(color: changed ? AppColors.accent : AppColors.fg12, width: changed ? 2 : 1)),
      child: ListTile(
        onTap: () => _editName(s),
        leading: Text(kind, style: const TextStyle(fontSize: 24)),
        title: Text('${CastStore.kuOf(s)} · ${CastStore.latinOf(s)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: changed ? Text('بەری: ${s.ku} · ${s.latin}', style: TextStyle(color: AppColors.fg54, fontSize: 12)) : null,
        trailing: Icon(Icons.edit_rounded, color: AppColors.fg54),
      ),
    );
  }

  Widget _charTile(MascotChar c) {
    final hidden = CastStore.hidden(c.id);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CharEditScreen(char: c, offline: widget.offline)))
          .then((_) => setState(() {})),
      child: Opacity(
        opacity: hidden ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.custom ? AppColors.gold : AppColors.fg12, width: c.custom ? 2 : 1.2),
          ),
          child: Column(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Image(image: c.img('base'), fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 3, 4, 7),
              child: Text('${hidden ? '🙈 ' : ''}${c.custom ? '✨ ' : ''}${c.name}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── ✏️ دەستکاری / کاراکتەرێ نوو ─────────────────────────

class CharEditScreen extends StatefulWidget {
  /// null = کاراکتەرێ نوو
  final MascotChar? char;
  final bool offline;
  const CharEditScreen({super.key, this.char, this.offline = false});

  @override
  State<CharEditScreen> createState() => _CharEditScreenState();
}

const _previewId = '__preview';

class _CharEditScreenState extends State<CharEditScreen> {
  late final bool isNew = widget.char == null;
  late final bool isCustom = isNew || widget.char!.custom;
  late final String id = widget.char?.id ?? 'u${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  late final TextEditingController name = TextEditingController(text: widget.char?.name ?? '');
  late String gender = widget.char?.gender ?? 'm';
  late bool hidden = CastStore.hidden(id);

  /// وێنەیێن نوو یێن هێشتا نەهاتینە پاراستن
  final Map<String, Uint8List> pending = {};
  final Set<String> removed = {};
  final Set<String> busy = {};
  List<double>? baseFrame;
  MascotMood mood = MascotMood.ask;
  bool saving = false;
  String progress = '';

  @override
  void initState() {
    super.initState();
    if (!isNew) CastStore.ensureImages(id).then((_) => _syncPreview());
    _syncPreview();
  }

  @override
  void dispose() {
    CastStore.images.remove(_previewId);
    super.dispose();
  }

  /// وێنەیێ نوکە یێ هەر جۆرەکی (یێ نوو، یێ پاراستی، یان یێ ئەپێ)
  ImageProvider? _current(String kind) {
    if (pending[kind] != null) return MemoryImage(pending[kind]!);
    if (removed.contains(kind)) return isCustom ? null : AssetImage('assets/mascot/${id}_$kind.webp');
    if (isCustom) {
      final b = CastStore.images[id]?[kind];
      return b == null ? null : MemoryImage(b);
    }
    return widget.char!.img(kind);
  }

  bool _hasOwn(String kind) =>
      pending.containsKey(kind) || (!removed.contains(kind) && (isCustom ? CastStore.images[id]?[kind] != null : CastStore.overrides(id).contains(kind)));

  void _syncPreview() {
    if (!isCustom) return;
    final m = <String, Uint8List>{...?CastStore.images[id]};
    for (final k in removed) {
      m.remove(k);
    }
    m.addAll(pending);
    CastStore.images[_previewId] = m;
    CastStore.changed.value++;
    if (mounted) setState(() {});
  }

  Future<void> _pick(String kind) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    setState(() => busy.add(kind));
    try {
      final bust = bustKinds.contains(kind);
      final r = await processCharImage(bytes, bust: bust, frame: (kind == 'blink' || kind == 'talk') ? baseFrame : null);
      if (kind == 'base') baseFrame = r.frame;
      pending[kind] = r.png;
      removed.remove(kind);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ وێنە نەهاتە خواندن: $e')));
    }
    busy.remove(kind);
    _syncPreview();
  }

  void _remove(String kind) {
    pending.remove(kind);
    removed.add(kind);
    _syncPreview();
  }

  Future<void> _save() async {
    final n = name.text.trim();
    if (isCustom && n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ناڤەکی بنڤیسە')));
      return;
    }
    if (isNew && !pending.containsKey('base')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🖼️ کێمترین: وێنەیێ «ئاسایی» زێدە بکە')));
      return;
    }
    setState(() => saving = true);
    final b = Backend.instance;
    String? err;
    var i = 0;
    for (final e in pending.entries) {
      i++;
      setState(() => progress = 'وێنە $i / ${pending.length}…');
      if (!widget.offline) err = await b.saveContent('charimg_${id}_${e.key}', base64Encode(e.value));
      if (err != null) break;
    }
    if (err == null) {
      for (final k in removed) {
        if (!widget.offline) await b.resetContent('charimg_${id}_$k');
      }
      // وێنە د ناڤ ئەپێ دا (بێ بارکرنەکا دی)
      final m = <String, Uint8List>{...?CastStore.images[id]};
      for (final k in removed) {
        m.remove(k);
      }
      m.addAll(pending);
      CastStore.images[id] = m;

      final entry = Map<String, dynamic>.from(CastStore.chars[id] ?? const {});
      if (hidden) {
        entry['hide'] = true;
      } else {
        entry.remove('hide');
      }
      if (isCustom) {
        final kinds = [for (final k in charKinds) if (m[k] != null) k];
        final c = CastStore.customById(id);
        if (c == null) {
          CastStore.custom.add(CustomChar(id, n, gender, kinds, DateTime.now().millisecondsSinceEpoch));
        } else {
          c
            ..name = n
            ..gender = gender
            ..kinds = kinds
            ..version = DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        if (n.isEmpty || n == widget.char!.baseName) {
          entry.remove('n');
        } else {
          entry['n'] = n;
        }
        final over = {...CastStore.overrides(id), ...pending.keys}..removeAll(removed);
        if (over.isEmpty) {
          entry.remove('k');
        } else {
          entry['k'] = [for (final k in charKinds) if (over.contains(k)) k];
        }
      }
      if (entry.isEmpty) {
        CastStore.chars.remove(id);
      } else {
        CastStore.chars[id] = entry;
      }
      setState(() => progress = 'پاراستن…');
      err = widget.offline ? null : await CastStore.save();
      CastStore.changed.value++;
    }
    if (!mounted) return;
    setState(() => saving = false);
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ هاتە پاراستن — ل نک هەمی فێرخوازان دیار دبیت')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $err')));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('🗑️ ژێبرنا کاراکتەری؟'),
          content: Text('«${name.text}» و هەمی وێنەیێن وی دێ هێنە ژێبرن.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نە')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ژێببە')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => saving = true);
    if (!widget.offline) await Backend.instance.deleteContentPrefix('charimg_${id}_');
    CastStore.custom.removeWhere((c) => c.id == id);
    CastStore.chars.remove(id);
    CastStore.images.remove(id);
    final err = widget.offline ? null : await CastStore.save();
    if (!mounted) return;
    setState(() => saving = false);
    if (err == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = isCustom
        ? MascotChar(_previewId, name.text, '', gender, custom: true)
        : widget.char!;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isNew ? '➕ کاراکتەرێ نوو' : '✏️ ${widget.char!.name}'),
          actions: [
            if (isCustom && !isNew)
              IconButton(tooltip: 'ژێبرن', icon: Icon(Icons.delete_outline_rounded, color: AppColors.red), onPressed: saving ? null : _delete),
          ],
        ),
        body: AbsorbPointer(
          absorbing: saving,
          child: ListView(padding: const EdgeInsets.all(14), children: [
            // 👀 پێشبینین
            Container(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                SizedBox(
                  height: 170,
                  child: Center(child: MascotView(key: ValueKey('$mood${pending.length}${removed.length}'), char: preview, mood: mood, height: 160)),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  for (final (m, t) in [
                    (MascotMood.ask, '🙂 ئاسایی'),
                    (MascotMood.speak, '🗣️ ئاخفتن'),
                    (MascotMood.happy, '😄 کەیف'),
                    (MascotMood.sad, '😟 خەم'),
                    (MascotMood.think, '🤔 هزر'),
                  ])
                    ChoiceChip(label: Text(t), selected: mood == m, onSelected: (_) => setState(() => mood = m)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'ناڤێ کاراکتەری',
                hintText: isNew ? 'بۆ نموونە: ڕێباز' : widget.char!.baseName,
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            if (isCustom) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Text('ڕەگەز:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                ChoiceChip(label: const Text('👨 کوڕ'), selected: gender == 'm', onSelected: (_) => setState(() => gender = 'm')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('👩 کچ'), selected: gender == 'f', onSelected: (_) => setState(() => gender = 'f')),
              ]),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: hidden,
              onChanged: (v) => setState(() => hidden = v),
              title: const Text('🙈 ڤەشارتن ژ فێرخوازان'),
              subtitle: Text('ل لیستا «کاراکتەرێ خۆ هەلبژێرە» و دیالۆگان دیار نابیت', style: TextStyle(fontSize: 12, color: AppColors.fg54)),
            ),
            const SizedBox(height: 6),
            Text('🖼️ وێنە', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
                'دەست ل چوارگۆشەیەکێ بدە و وێنەیێ وێ هەلبژێرە. پشتا کەسک یان ڤالا (PNG) ب خۆ دهێتە ژێبرن.'
                '${isNew ? ' کێمترین: «ئاسایی». وێنەیێن کێم ب وێنەیێ ئاسایی و لڤینێن کۆدی کار دکەن.' : ''}',
                style: TextStyle(color: AppColors.fg60, fontSize: 13)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
              children: [for (final k in charKinds) _slot(k)],
            ),
            const SizedBox(height: 18),
            if (saving)
              Column(children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                Text(progress, style: TextStyle(color: AppColors.fg60)),
              ])
            else
              BigButton(label: 'پاراستن', icon: Icons.check_rounded, onPressed: _save),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  Widget _slot(String kind) {
    final img = _current(kind);
    final own = _hasOwn(kind);
    final isPending = pending.containsKey(kind);
    return GestureDetector(
      onTap: busy.contains(kind) ? null : () => _pick(kind),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isPending ? AppColors.green : (own ? AppColors.accent : AppColors.fg24), width: isPending || own ? 2.2 : 1.4),
        ),
        child: Stack(children: [
          Column(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: busy.contains(kind)
                    ? const Center(child: CircularProgressIndicator())
                    : img == null
                        ? Center(child: Icon(Icons.add_photo_alternate_rounded, size: 34, color: AppColors.fg38))
                        : Image(image: img, fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 3, 6),
              child: Text('${charKinds.indexOf(kind) + 1}. ${charKindNames[kind]}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
          if (own && !busy.contains(kind))
            PositionedDirectional(
              top: 2,
              end: 2,
              child: GestureDetector(
                onTap: () => _remove(kind),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
