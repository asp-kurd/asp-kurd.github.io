/// 🎯 بەراوردکرنا تشتێ تە گۆتی دگەل رستا دروست (پەیڤ ب پەیڤ)
class SpeechScore {
  final int percent;
  final List<(String, bool)> words; // پەیڤێن رستێ: دروست هاتە گۆتن یان نە
  final String heard;
  const SpeechScore(this.percent, this.words, this.heard);
}

String _n(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

SpeechScore scoreSpeech(String target, List<String> heard) {
  final tw = target.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && _n(w).isNotEmpty).toList();
  if (tw.isEmpty) return const SpeechScore(0, [], '');
  SpeechScore best = SpeechScore(0, [for (final w in tw) (w, false)], heard.isEmpty ? '' : heard.first);
  for (final h in heard) {
    final pool = _n(h).split(' ').where((w) => w.isNotEmpty).toList();
    final marks = <(String, bool)>[];
    var ok = 0;
    for (final w in tw) {
      final k = _n(w);
      final i = pool.indexOf(k);
      // ژمارە (zwei ⇄ 2) و پەیڤێن نێزیک (ب ئێک پیتێ جودا) ژی قەبوول دکەین
      final near = i >= 0 ? i : pool.indexWhere((p) => _close(p, k));
      if (near >= 0) {
        pool.removeAt(near);
        ok++;
        marks.add((w, true));
      } else {
        marks.add((w, false));
      }
    }
    final pct = (ok * 100 / tw.length).round();
    if (pct > best.percent) best = SpeechScore(pct, marks, h);
  }
  return best;
}

const _nums = {'1': 'eins', '2': 'zwei', '3': 'drei', '4': 'vier', '5': 'fuenf', '6': 'sechs', '7': 'sieben', '8': 'acht', '9': 'neun', '10': 'zehn'};

bool _close(String a, String b) {
  if (_nums[a] == b || _nums[b] == a) return true;
  if ((a.length - b.length).abs() > 1 || b.length < 4) return false;
  // جوداهیا ئێک پیتێ (Levenshtein ≤ 1)
  var i = 0, j = 0, diff = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
      continue;
    }
    if (++diff > 1) return false;
    if (a.length > b.length) {
      i++;
    } else if (b.length > a.length) {
      j++;
    } else {
      i++;
      j++;
    }
  }
  return diff + (a.length - i) + (b.length - j) <= 1;
}
