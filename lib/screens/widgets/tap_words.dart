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

  /// ✨ پەیڤێن نوو (ب پیتێن بچووک): جارا ئێکێ ب نیشانا «نوو» دیار دبن
  final Set<String> chips;
  const TapWords(this.text, {super.key, required this.lang, required this.style, this.textAlign = TextAlign.center, this.chips = const {}});

  /// پارچەیێن دەقی وەکی span (بۆ Text.rich یێ دەرەکی) — دڤێت [recognizers] پاشی dispose ببن
  /// [chips]: پەیڤێن نوو (ب پیتێن بچووک) کو نیشانا «نوو» وەردگرن (ئێک جار)؛ [base] ستایلا دەقی
  static List<InlineSpan> spans(BuildContext context, String text, AppLanguage lang, List<GestureRecognizer> recognizers,
      {Set<String>? chips, TextStyle? base}) {
    final out = <InlineSpan>[];
    final left = {...?chips};
    var last = 0;
    for (final m in Glossary.wordRe.allMatches(text)) {
      if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start)));
      final w = m.group(0)!;
      final g = Glossary.lookup(w, lang);
      if (left.remove(w.toLowerCase())) {
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: NewWordChip(w, style: base, onTap: g == null ? null : (pos) => showGloss(context, w, g, pos, articles: lang == AppLanguage.german)),
        ));
      } else if (g == null) {
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

  static bool _routed = false;
  static void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) hide();
  }

  static void hide() {
    _timer?.cancel();
    _open?.remove();
    _open = null;
    if (_routed) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
      _routed = false;
    }
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
        Positioned(
          left: left,
          width: w,
          top: above ? null : at.dy + 22,
          bottom: above ? size.height - at.dy + 20 : null,
          child: IgnorePointer(
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
          )),
        ),
      ]),
    );
    overlay.insert(_open!);
    // هەر دەستلێدانەک ل هەر جهەکی ➔ بالۆن دهێتە گرتن (و دەستلێدان ب خۆ کارێ خۆ دکەت)
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _routed = true;
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
      TextSpan(children: TapWords.spans(context, widget.text, widget.lang, _rec, chips: widget.chips, base: widget.style)),
      textDirection: widget.lang.direction,
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }
}


/// ✨ پەیڤەکا نوو د رستێ دا: رەنگێ مۆر ب هایلایتەکێ نەرم و نیشانەکا بچووک «نوو»
/// (تنێ جارا ئێکێ کو ئەڤ پەیڤە دیار دبیت)
class NewWordChip extends StatelessWidget {
  final String word;
  final TextStyle? style;
  final void Function(Offset)? onTap;
  const NewWordChip(this.word, {super.key, this.style, this.onTap});

  static const _a = Color(0xFFA855F7), _b = Color(0xFFEC4899);

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.dark ? const Color(0xFFE2C2FF) : const Color(0xFF7C2BD9);
    final base = (style ?? DefaultTextStyle.of(context).style).copyWith(color: ink, fontWeight: FontWeight.w800);
    return GestureDetector(
      onTapUp: onTap == null ? null : (d) => onTap!(d.globalPosition),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Stack(clipBehavior: Clip.none, children: [
          // هایلایتێ نەرم کو ژ چەپێ بۆ راستێ دهێتە کێشان (وەکی قەلەما نیشانکرنێ)
          Positioned(
            left: 0,
            bottom: (base.fontSize ?? 20) * 0.08,
            child: Container(
              width: null,
              height: (base.fontSize ?? 20) * 0.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(colors: [_a.withValues(alpha: 0.38), _b.withValues(alpha: 0.30)]),
              ),
              child: Opacity(opacity: 0, child: Text(word, style: base)),
            ).clipWidth(v),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: Text(word, style: base)),
          // نیشانا بچووک ل سەر پەیڤێ
          Positioned(
            top: -(base.fontSize ?? 20) * 0.42,
            right: -6,
            child: Opacity(
              opacity: v,
              child: Transform.scale(
                scale: 0.6 + 0.4 * v,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_a, _b]),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: _b.withValues(alpha: 0.4), blurRadius: 6)],
                  ),
                  child: const Text('نوو', style: TextStyle(fontSize: 10, height: 1.2, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

extension on Widget {
  /// تنێ پشکا [f] (٠–١) ژ پانیێ دیار دکەت
  Widget clipWidth(double f) => ClipRect(child: Align(alignment: Alignment.centerLeft, widthFactor: f.clamp(0.001, 1.0), child: this));
}
