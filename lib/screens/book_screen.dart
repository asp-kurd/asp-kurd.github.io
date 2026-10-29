import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/book.dart';
import '../models.dart';
import '../services/progress_service.dart';
import '../services/voice_service.dart';
import '../ui.dart';

/// 📖 پەرتووکا رێزمانێ: «A1.1 mit Poya» — ٢٠ بەش، ژ ئەلفوبێ هەتا Perfekt
/// ناڤەرۆک هەردەم ب بادینییە (پەرتووکا ئەلمانی ب بادینی)، لەوما RTL دمینیت.

// ───────── پێشکەفتنا خواندنێ ─────────
class BookProgress extends ChangeNotifier {
  BookProgress._();
  static final instance = BookProgress._();
  static const _key = 'book_read_v1';
  Set<String> read = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    read = (p.getStringList(_key) ?? []).toSet();
    _loaded = true;
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    if (!read.add(id)) return;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, read.toList());
    notifyListeners();
  }
}

// ───────── هاریکار: ئاراستەیا دەقی، bold، دەنگ ─────────
final _latin = RegExp(r'[A-Za-zÄÖÜäöüß]');
final _arabic = RegExp(r'[؀-ۿ]');

/// ئاراستە ل دویڤ ئێکەم پیتا ب هێز (وەکی dir="auto")
TextDirection dirOf(String s) {
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    if (_latin.hasMatch(ch)) return TextDirection.ltr;
    if (_arabic.hasMatch(ch)) return TextDirection.rtl;
  }
  return TextDirection.rtl;
}

bool isGermanOnly(String s) => _latin.hasMatch(s) && !_arabic.hasMatch(s);

String plain(String s) => s.replaceAll('**', '').trim();

/// «**bold**» ➔ TextSpan
TextSpan richSpan(String s, TextStyle base, {Color? boldColor}) {
  final parts = s.split('**');
  return TextSpan(
    style: base,
    children: [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty)
          TextSpan(
            text: parts[i],
            style: i.isOdd ? TextStyle(fontWeight: FontWeight.bold, color: boldColor ?? AppColors.gold) : null,
          ),
    ],
  );
}

Widget rich(String s, {double size = 16, Color color = Colors.white, TextAlign? align, Color? boldColor}) {
  return Text.rich(
    richSpan(s, TextStyle(fontSize: size, color: color, height: 1.6), boldColor: boldColor),
    textDirection: dirOf(s),
    textAlign: align ?? TextAlign.start,
  );
}

Future<void> sayGerman(String text) => VoiceService.instance.speakText(plain(text), AppLanguage.german);

Color genderColor(String g) => switch (g) {
      'der' => AppColors.blue,
      'die' => AppColors.red,
      'das' => AppColors.green,
      _ => Colors.white,
    };

// ───────── لیستا بەشان ─────────
class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final bp = BookProgress.instance;

  @override
  void initState() {
    super.initState();
    bp.load();
  }

  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListenableBuilder(
        listenable: bp,
        builder: (context, _) {
          if (bookChapters.isEmpty) {
            return const Center(child: Text('📖 …'));
          }
          final done = bookChapters.where((c) => bp.read.contains(c.id)).length;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _cover(done, n),
                const SizedBox(height: 8),
                for (final part in bookParts) ...[
                  _partHeader(part.title(n)),
                  for (var i = 0; i < bookChapters.length; i++)
                    if (bookChapters[i].part == part.id) _chapterTile(context, i),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cover(int done, AppLanguage n) {
    final total = bookChapters.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFED2024), Color(0xFFFFC800), Color(0xFF278E43)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('📖', style: TextStyle(fontSize: 34)),
          SizedBox(width: 10),
          Expanded(
            child: Text('A1.1 mit Poya',
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(tr(n, 'رێبەرا ئەلمانی ب بادینی — ژ سفرێ هەتا A2', 'Deutsch-Grammatik auf Badini — von 0 bis A2',
                'German grammar in Badini — from zero to A2'),
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 10,
            backgroundColor: Colors.black26,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(tr(n, '$done ژ $total بەشان هاتنە خواندن', '$done von $total Kapiteln gelesen', '$done of $total chapters read'),
            style: const TextStyle(color: Colors.white)),
      ]),
    );
  }

  Widget _partHeader(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _chapterTile(BuildContext context, int i) {
    final c = bookChapters[i];
    final (no, name) = c.split;
    final read = bp.read.contains(c.id);
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: read ? AppColors.green : Colors.transparent, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: c.color,
          child: Icon(read ? Icons.check_rounded : c.icon, color: Colors.white),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: no.isEmpty ? null : Text(no, style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterScreen(index: i))),
      ),
    );
  }
}

// ───────── خواندنا بەشەکێ ─────────
class ChapterScreen extends StatelessWidget {
  final int index;
  const ChapterScreen({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = bookChapters[index];
    final (no, name) = c.split;
    final hasNext = index + 1 < bookChapters.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: c.color,
          foregroundColor: Colors.white,
          toolbarHeight: 76,
          title: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (no.isNotEmpty) Text(no, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            for (final b in c.blocks) Padding(padding: const EdgeInsets.only(bottom: 14), child: _block(b, c.color)),
            const SizedBox(height: 8),
            BigButton(
              label: hasNext ? 'خواند ✓ — بەشێ دی' : 'خواند ✓',
              icon: hasNext ? Icons.arrow_forward_rounded : Icons.check_rounded,
              color: c.color,
              onPressed: () async {
                await BookProgress.instance.markRead(c.id);
                if (!context.mounted) return;
                if (hasNext) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChapterScreen(index: index + 1)));
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _block(BookBlock b, Color accent) {
    switch (b.type) {
      case 'h':
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Container(width: 5, height: 24, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 10),
            Expanded(child: rich(b.text, size: 19, color: Colors.white)),
          ]),
        );
      case 'p':
        final isNote = b.text.startsWith('**');
        if (!isNote) return rich(b.text);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: const Border(right: BorderSide(color: AppColors.gold, width: 4)),
          ),
          child: rich(b.text),
        );
      case 'ul':
      case 'ol':
        return Column(children: [
          for (var i = 0; i < b.items.length; i++) _listItem(b.items[i], b.type == 'ol' ? '${i + 1}' : '•', accent),
        ]);
      case 'table':
        return _BookTable(head: b.head, rows: b.rows, accent: accent);
      case 'vocab':
        return _VocabGrid(gender: b.gender, items: b.rows);
      case 'quiz':
        return _QuizBlock(items: b.quiz, why: b.text, accent: accent);
      default:
        return const SizedBox.shrink();
    }
  }

  /// بۆ رستێن «German — کوردی» دوگمەیا دەنگی زێدە دبیت
  Widget _listItem(String s, String marker, Color accent) {
    String? german;
    final dash = s.indexOf(' — ');
    if (dash > 0) {
      final left = plain(s.substring(0, dash)).replaceFirst(RegExp(r'^[^:]{1,20}:\s*'), '');
      if (isGermanOnly(left)) german = left;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 24,
          child: Text(marker, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16, height: 1.6)),
        ),
        Expanded(child: rich(s)),
        if (german != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.volume_up_rounded, color: accent, size: 22),
            onPressed: () => sayGerman(german!),
          ),
      ]),
    );
  }
}

// ───────── خشتە (ب ستوونێن ئەلمانی یێن ب دەنگ) ─────────
class _BookTable extends StatelessWidget {
  final List<String> head;
  final List<List<String>> rows;
  final Color accent;
  const _BookTable({required this.head, required this.rows, required this.accent});

  @override
  Widget build(BuildContext context) {
    final maxCell = head.length <= 3 ? 260.0 : 190.0;
    Widget cell(String s, {bool header = false}) {
      final german = !header && isGermanOnly(s);
      final child = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxCell, minWidth: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text.rich(
            richSpan(
              s,
              TextStyle(
                fontSize: header ? 14 : 15,
                height: 1.45,
                fontWeight: header ? FontWeight.bold : FontWeight.normal,
                color: header ? Colors.white : (german ? const Color(0xFFBEE9FF) : Colors.white),
              ),
            ),
            textDirection: dirOf(s),
          ),
        ),
      );
      if (!german) return child;
      return InkWell(onTap: () => sayGerman(s), child: child);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder.symmetric(inside: const BorderSide(color: Colors.white10)),
          children: [
            TableRow(
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.85)),
              children: [for (final h in head) cell(h, header: true)],
            ),
            for (var r = 0; r < rows.length; r++)
              TableRow(
                decoration: BoxDecoration(color: r.isEven ? AppColors.card : const Color(0xFF1A282E)),
                children: [
                  for (var c = 0; c < head.length; c++) cell(c < rows[r].length ? rows[r][c] : ''),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ───────── فەرهەنگۆک: کارتێن رەنگکری + خۆ تاقیکرن ─────────
class _VocabGrid extends StatefulWidget {
  final String gender;
  final List<List<String>> items;
  const _VocabGrid({required this.gender, required this.items});

  @override
  State<_VocabGrid> createState() => _VocabGridState();
}

class _VocabGridState extends State<_VocabGrid> {
  bool quizMode = false;
  final shown = <int>{};

  @override
  Widget build(BuildContext context) {
    final col = genderColor(widget.gender);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeTrackColor: col,
        title: const Text('خۆ تاقی بکە (رامان ڤەشێرە)'),
        value: quizMode,
        onChanged: (v) => setState(() {
          quizMode = v;
          shown.clear();
        }),
      ),
      LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - 10) / 2;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < widget.items.length; i++)
            SizedBox(
              width: w,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  sayGerman(widget.items[i][0]);
                  if (quizMode) setState(() => shown.add(i));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border(right: BorderSide(color: col, width: 4)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.items[i][0],
                        textDirection: TextDirection.ltr,
                        style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      quizMode && !shown.contains(i) ? '؟ ؟ ؟' : widget.items[i][1],
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    ]);
  }
}

// ───────── راهێنان: بەرسڤا ڤەشارتی ─────────
class _QuizBlock extends StatefulWidget {
  final List<QuizItem> items;
  final String why;
  final Color accent;
  const _QuizBlock({required this.items, required this.why, required this.accent});

  @override
  State<_QuizBlock> createState() => _QuizBlockState();
}

class _QuizBlockState extends State<_QuizBlock> {
  final shown = <int>{};

  /// رستا تەمام ب بەرسڤێ: ______ ➔ بەرسڤ، (habe / bin) ➔ bin، (der) ➔ نامینیت
  static String filled(QuizItem it) {
    var q = it.q;
    final arrow = q.indexOf('→');
    if (arrow >= 0) q = q.substring(arrow + 1).trim();
    final answers = it.a.split(' / ');
    var k = 0;
    q = q.replaceAllMapped(RegExp(r'_{3,}'), (_) => k < answers.length ? answers[k++] : '…');
    if (k == 0) q = q.replaceFirst(RegExp(r'\([^)]*/[^)]*\)'), it.a);
    q = q.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    return q.replaceAllMapped(RegExp(r'\s+([.?!,])'), (m) => m[1]!);
  }

  @override
  Widget build(BuildContext context) {
    final all = shown.length == widget.items.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < widget.items.length; i++) _item(i),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(() => all ? shown.clear() : shown.addAll(List.generate(widget.items.length, (i) => i))),
          icon: Icon(all ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          label: Text(all ? 'هەمیان ڤەشێرە' : 'هەمی بەرسڤان نیشان بدە'),
        ),
      ),
      if (shown.isNotEmpty && widget.why.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: rich('💡 ${widget.why}', size: 15),
        ),
    ]);
  }

  Widget _item(int i) {
    final it = widget.items[i];
    final open = shown.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: open ? AppColors.green : Colors.white12, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${i + 1}. ${it.q}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 16, height: 1.5)),
        const SizedBox(height: 8),
        if (!open)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: () => setState(() => shown.add(i)),
              child: const Text('بەرسڤ'),
            ),
          )
        else
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(filled(it),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: AppColors.green),
              onPressed: () => sayGerman(filled(it)),
            ),
          ]),
      ]),
    );
  }
}
