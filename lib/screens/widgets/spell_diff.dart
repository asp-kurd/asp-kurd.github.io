import 'package:flutter/material.dart';

import '../../ui.dart';

/// ✍️ راستکرنا نڤیسینێ پیت ب پیت:
///   keno  ➔  Kino
/// پیتێن خەلەت ب سۆر (خەت ل سەر) · پیتێن دروست ب کەسک (ستوور)
class SpellDiff extends StatelessWidget {
  final List<(String, String)> fixes;
  const SpellDiff(this.fixes, {super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          for (final (given, correct) in fixes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text.rich(TextSpan(children: _spans(given, correct, wrongSide: true))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.fg54),
                ),
                Text.rich(TextSpan(children: _spans(given, correct, wrongSide: false))),
              ]),
            ),
        ],
      ),
    );
  }

  /// پیتێن هەڤبەش ب ڕەنگێ ئاسایی، یێن جودا ب سۆر (یا تە) یان کەسک (یا دروست)
  static List<TextSpan> _spans(String a, String b, {required bool wrongSide}) {
    final base = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.fg);
    final bad = TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.red,
        decoration: TextDecoration.lineThrough,
        decorationColor: AppColors.red,
        decorationThickness: 2);
    final good = TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.green,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.green,
        decorationThickness: 2);
    // LCS (پیت ب پیت، بێ جوداهیا پیتا مەزن/بچووک بۆ رێکخستنێ)
    final x = a.toLowerCase(), y = b.toLowerCase();
    final n = x.length, m = y.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        dp[i][j] = x[i] == y[j] ? dp[i + 1][j + 1] + 1 : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
      }
    }
    final out = <TextSpan>[];
    var i = 0, j = 0;
    void add(String ch, TextStyle st) {
      if (out.isNotEmpty && out.last.style == st) {
        out[out.length - 1] = TextSpan(text: out.last.text! + ch, style: st);
      } else {
        out.add(TextSpan(text: ch, style: st));
      }
    }

    while (i < n || j < m) {
      if (i < n && j < m && x[i] == y[j]) {
        // پیتا مەزن/بچووک: ئەگەر جودا بیت، وەکی خەلەتی نیشان بدە
        final same = a[i] == b[j];
        if (wrongSide) {
          add(a[i], same ? base : bad);
        } else {
          add(b[j], same ? base : good);
        }
        i++;
        j++;
      } else if (j < m && (i >= n || dp[i][j + 1] >= dp[i + 1][j])) {
        if (!wrongSide) add(b[j], good);
        j++;
      } else {
        if (wrongSide) add(a[i], bad);
        i++;
      }
    }
    return out;
  }
}
