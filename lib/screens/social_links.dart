import 'package:flutter/material.dart';

import '../data/links.dart';
import '../services/push_stub.dart' if (dart.library.js_interop) '../services/push_web.dart' show openExternal;
import '../ui.dart';

/// ⭕ ئایکۆنا لینکەکێ (بازنەکا رەنگین)
class LinkBadge extends StatelessWidget {
  final LinkKind kind;
  final double size;
  const LinkBadge(this.kind, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) {
    final fg = kind.id == 'snapchat' ? Colors.black : Colors.white;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: kind.colors),
        boxShadow: [BoxShadow(color: kind.colors.first.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: kind.icon != null
          ? Icon(kind.icon, color: fg, size: size * 0.56)
          : Text(kind.glyph ?? '?', style: TextStyle(color: fg, fontSize: size * 0.42, fontWeight: FontWeight.w900, height: 1)),
    );
  }
}

/// 🔗 لینکێن ASP د پرۆفایلێ دا (ئەوێن ئەدمینی داناین)
class SocialLinksRow extends StatefulWidget {
  const SocialLinksRow({super.key});
  @override
  State<SocialLinksRow> createState() => _SocialLinksRowState();
}

class _SocialLinksRowState extends State<SocialLinksRow> {
  @override
  void initState() {
    super.initState();
    SocialLinks.refresh().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = SocialLinks.items;
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🔗 ASP ل تۆڕێن جڤاکی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 12, children: [
          for (final l in items)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => openExternal(l.href),
              child: SizedBox(
                width: 68,
                child: Column(children: [
                  LinkBadge(linkKind(l.kind)),
                  const SizedBox(height: 5),
                  Text(l.label.isNotEmpty ? l.label : linkKind(l.kind).name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.fg70, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// 🛡️ ئەدمین: رێڤەبرنا لینکێن پەیوەندیێ (ئایکۆنێ هەلبژێرە ➔ لینکی بنڤیسە)
class SocialLinksEditor extends StatefulWidget {
  const SocialLinksEditor({super.key});
  @override
  State<SocialLinksEditor> createState() => _SocialLinksEditorState();
}

class _SocialLinksEditorState extends State<SocialLinksEditor> {
  List<SocialLink> list = [];
  bool loading = true, saving = false;

  @override
  void initState() {
    super.initState();
    SocialLinks.refresh().then((_) {
      if (mounted) {
        setState(() {
          list = List.of(SocialLinks.items);
          loading = false;
        });
      }
    });
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final err = await SocialLinks.save(list);
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err == null ? '✅ هاتە پاراستن — فێرخواز د پرۆفایلێ دا دبینن' : '❌ $err')));
  }

  Future<void> _edit({int? index}) async {
    final old = index == null ? null : list[index];
    var kind = old?.kind ?? 'facebook';
    final url = TextEditingController(text: old?.url ?? '');
    final label = TextEditingController(text: old?.label ?? '');
    final res = await showModalBottomSheet<SocialLink>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('١) ئایکۆنێ هەلبژێرە', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final k in linkKinds)
                    GestureDetector(
                      onTap: () => setS(() => kind = k.id),
                      child: Container(
                        width: 70,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: kind == k.id ? AppColors.accent.withValues(alpha: 0.16) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kind == k.id ? AppColors.accent : AppColors.fg12, width: kind == k.id ? 2.5 : 1.5),
                        ),
                        child: Column(children: [
                          LinkBadge(k, size: 40),
                          const SizedBox(height: 4),
                          Text(k.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                        ]),
                      ),
                    ),
                ]),
                const SizedBox(height: 16),
                const Text('٢) لینکی بنڤیسە', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: url,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(hintText: linkKind(kind).hint, hintTextDirection: TextDirection.ltr, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: label,
                  maxLength: 18,
                  decoration: const InputDecoration(labelText: 'ناڤ ل بن ئایکۆنێ (نە پێدڤییە)', border: OutlineInputBorder(), counterText: ''),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (url.text.trim().isEmpty) return;
                      Navigator.pop(ctx, SocialLink(kind, url.text.trim(), label.text.trim()));
                    },
                    child: const Padding(padding: EdgeInsets.all(12), child: Text('دانە', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (res == null) return;
    setState(() {
      if (index == null) {
        list.add(res);
      } else {
        list[index] = res;
      }
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('🔗 لینکێن پەیوەندیێ')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: saving ? null : () => _edit(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('لینکەکێ زێدە بکە'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
                Text('ئەڤ لینکە د پرۆفایلا هەمی فێرخوازان دا دیار دبن. ئایکۆنێ هەلبژێرە (Facebook، TikTok …) و لینکێ خۆ بدانە.',
                    style: TextStyle(color: AppColors.fg70, height: 1.6)),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(child: Text('هێشتا چ لینک نینن ➕', style: TextStyle(color: AppColors.fg54, fontSize: 16))),
                  ),
                for (var i = 0; i < list.length; i++)
                  Card(
                    child: ListTile(
                      leading: LinkBadge(linkKind(list[i].kind), size: 42),
                      title: Text(list[i].label.isNotEmpty ? list[i].label : linkKind(list[i].kind).name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(list[i].url, textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _edit(index: i),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (i > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_upward_rounded),
                            onPressed: () {
                              setState(() => list.insert(i - 1, list.removeAt(i)));
                              _save();
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                          onPressed: () {
                            setState(() => list.removeAt(i));
                            _save();
                          },
                        ),
                      ]),
                    ),
                  ),
              ]),
      ),
    );
  }
}
