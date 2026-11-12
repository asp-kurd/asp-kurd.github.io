import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/glossary.dart';
import '../../models.dart';
import '../../ui.dart';

/// 👆 رستەیەک کو هەر پەیڤەکا وێ دهێتە تبلکرن ➔ رامان + ئارتیکل (وەکی تێبینیەک ل سەر پەیڤێ)
/// [before]/[after]: پارچەیێن دی یێن هەمان دەقی (بۆ نموونە جهێ ڤالا)
class TapWords extends StatefulWidget {
  final String text;
  final AppLanguage lang;
  final TextStyle style;
  final TextAlign textAlign;
  const TapWords(this.text, {super.key, required this.lang, required this.style, this.textAlign = TextAlign.center});

  /// پارچەیێن دەقی وەکی span (بۆ Text.rich یێ دەرەکی) — دڤێت [recognizers] پاشی dispose ببن
  static List<InlineSpan> spans(BuildContext context, String text, AppLanguage lang, List<GestureRecognizer> recognizers) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in Glossary.wordRe.allMatches(text)) {
      if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start)));
      final w = m.group(0)!;
      final g = Glossary.lookup(w, lang);
      if (g == null) {
        out.add(TextSpan(text: w));
      } else {
        final r = TapGestureRecognizer()..onTapUp = (d) => showGloss(context, w, g, d.globalPosition, articles: lang == AppLanguage.german);
        recognizers.add(r);
        out.add(TextSpan(
          text: w,
          recognizer: r,
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: AppColors.fg38,
            decorationThickness: 1.6,
          ),
        ));
      }
      last = m.end;
    }
    if (last < text.length) out.add(TextSpan(text: text.substring(last)));
    return out;
  }

  static OverlayEntry? _open;
  static Timer? _timer;

  static void hide() {
    _timer?.cancel();
    _open?.remove();
    _open = null;
  }

  /// 💬 بالۆنا رامانێ ل سەر پەیڤێ
  static void showGloss(BuildContext context, String shown, Gloss g, Offset at, {bool articles = true}) {
    hide();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final size = MediaQuery.of(context).size;
    const w = 250.0;
    final left = (at.dx - w / 2).clamp(12.0, size.width - w - 12.0);
    final above = at.dy > 230;
    final artColor = switch (g.article) {
      'der' => const Color(0xFF1CB0F6),
      'die' => const Color(0xFFFF4B6E),
      'das' => const Color(0xFF58CC02),
      _ => AppColors.fg,
    };
    final genderKu = g.plural ? 'کۆم' : switch (g.article) { 'der' => 'نێر', 'die' => 'مێ', 'das' => 'بێلایەن', _ => '' };
    _open = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: hide, onPanDown: (_) => hide())),
        Positioned(
          left: left,
          width: w,
          top: above ? null : at.dy + 22,
          bottom: above ? size.height - at.dy + 20 : null,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // der Tisch
                  Text.rich(
                    TextSpan(children: [
                      if (g.article.isNotEmpty && !g.plural)
                        TextSpan(text: '${g.article} ', style: TextStyle(color: artColor, fontWeight: FontWeight.w900)),
                      TextSpan(text: shown),
                    ]),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.germanText),
                  ),
                  const SizedBox(height: 6),
                  Text(g.ku,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.fg, height: 1.5)),
                  // 📌 تێبینی: ئارتیکل هەیە یان نە (بۆ ئینگلیزی تنێ فۆرما بنەڕەت)
                  if (articles || g.base.isNotEmpty) const SizedBox(height: 8),
                  if (articles || g.base.isNotEmpty) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.cardAlt, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      [
                        if (articles)
                          if (g.name)
                            '📛 ناڤ — ئارتیکل نینە'
                          else if (g.article.isNotEmpty)
                            '📌 ئارتیکل: ${g.article} ($genderKu)'
                          else
                            '📌 ئارتیکل نینە',
                        if (g.base.isNotEmpty) '↩ ژ: ${g.base}',
                      ].join('   ·   '),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: g.article.isNotEmpty ? artColor : AppColors.fg60, fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
    overlay.insert(_open!);
    _timer = Timer(const Duration(seconds: 6), hide);
  }

  @override
  State<TapWords> createState() => _TapWordsState();
}

class _TapWordsState extends State<TapWords> {
  final _rec = <GestureRecognizer>[];

  void _clear() {
    for (final r in _rec) {
      r.dispose();
    }
    _rec.clear();
  }

  @override
  void dispose() {
    _clear();
    TapWords.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    return Text.rich(
      TextSpan(children: TapWords.spans(context, widget.text, widget.lang, _rec)),
      textDirection: widget.lang.direction,
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }
}
