import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/backend.dart';

/// 👥 کاراکتەر و ناڤێن ناڤ رستان — ئەدمین دشێت بگوهۆڕیت (خشتا content، کلیل: cast)
///
/// - names  : ناڤێن ناڤ رستان (سەفین ➔ ناڤەکێ دی) — دەمێ بارکرنا ناڤەرۆکێ دهێنە گوهۆڕین
/// - chars  : ناڤ / ڤەشارتنا ١٤ کاراکتەرێن 3D
/// - custom : کاراکتەرێن نوو یێن ئەدمینی (وێنە د content: charimg_<id>_<kind> دا)
class StoryName {
  final String id, latin, kuLat, ku, gender; // gender: m / f / s (ناڤێ بنەمالێ)
  const StoryName(this.id, this.latin, this.kuLat, this.ku, this.gender);
}

const storyNames = <StoryName>[
  StoryName('safin', 'Safin', 'Safîn', 'سەفین', 'm'),
  StoryName('avin', 'Avin', 'Avîn', 'ئاڤین', 'f'),
  StoryName('poya', 'Poya', 'Poya', 'پۆیا', 'm'),
  StoryName('dilin', 'Dilin', 'Dilîn', 'دیلین', 'f'),
  StoryName('dilhin', 'Dilhin', 'Dilhîn', 'دیلهین', 'f'),
  StoryName('huda', 'Huda', 'Hûda', 'هوودا', 'f'),
  StoryName('metin', 'Metin', 'Metîn', 'مەتین', 'm'),
  StoryName('samad', 'Samad', 'Samad', 'سەمەد', 'm'),
  StoryName('bnar', 'Bnar', 'Bnar', 'بنار', 'm'),
  StoryName('mohammed', 'Mohammed', 'Mihemed', 'محەمەد', 'm'),
  StoryName('lana', 'Lana', 'Lana', 'لانا', 'f'),
  StoryName('sherwan', 'Sherwan', 'Şêrwan', 'شێروان', 'm'),
  StoryName('kocer', 'Koçer', 'Koçer', 'کۆچەر', 's'),
  StoryName('nerweyi', 'Nerweyi', 'Nerweyî', 'نێروەیی', 's'),
  StoryName('duski', 'Duski', 'Duskî', 'دۆسکی', 's'),
];

/// وێنەیێن هەر کاراکتەرەکی (١٠) — ب رێزبەندی
const charKinds = <String>['base', 'blink', 'talk', 'happy', 'sad', 'think', 'full', 'happy_full', 'fly_full', 'land_full'];
const charKindNames = <String, String>{
  'base': 'ئاسایی',
  'blink': 'چاڤ گرتی',
  'talk': 'ئاخفتن',
  'happy': 'کەیف',
  'sad': 'خەم',
  'think': 'هزر',
  'full': 'لەشێ تەمام',
  'happy_full': 'کەیفا لەشێ تەمام',
  'fly_full': 'فڕین',
  'land_full': 'هاتنە خوارێ',
};
const bustKinds = {'base', 'blink', 'talk', 'happy', 'sad', 'think'};

/// ئەگەر وێنەیەک نەبیت، کیژ وێنە ل جهێ وێ
const _fallback = <String, List<String>>{
  'blink': ['base'],
  'talk': ['base'],
  'happy': ['base'],
  'sad': ['base'],
  'think': ['base'],
  'full': ['base'],
  'happy_full': ['full', 'happy', 'base'],
  'fly_full': ['full', 'base'],
  'land_full': ['full', 'base'],
};

class CustomChar {
  final String id;
  String name, gender;
  List<String> kinds; // کیژ وێنە هەنە
  int version;
  CustomChar(this.id, this.name, this.gender, this.kinds, this.version);

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'g': gender, 'k': kinds, 'v': version};
  factory CustomChar.fromJson(Map j) => CustomChar(
        '${j['id']}',
        '${j['n'] ?? ''}',
        '${j['g'] ?? 'm'}',
        [for (final k in (j['k'] as List? ?? const [])) '$k'],
        (j['v'] as num?)?.toInt() ?? 0,
      );
}

class CastStore {
  CastStore._();

  /// id ➔ {l: لاتینی, k: کوردی}
  static Map<String, Map<String, String>> names = {};

  /// id ➔ {n: ناڤ, hide: true}
  static Map<String, Map<String, dynamic>> chars = {};
  static List<CustomChar> custom = [];

  /// وێنەیێن کاراکتەرێن نوو: id ➔ kind ➔ bytes
  static final Map<String, Map<String, Uint8List>> images = {};
  static final Map<String, Future<void>> _loading = {};

  /// دەمێ وێنە دگەهن، شاشە ژ نوی دهێنە کێشان
  static final ValueNotifier<int> changed = ValueNotifier(0);

  static void _parse(String? raw) {
    names = {};
    chars = {};
    custom = [];
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in ((j['names'] as Map?) ?? const {}).entries) {
        final v = e.value as Map;
        final l = '${v['l'] ?? ''}'.trim(), k = '${v['k'] ?? ''}'.trim();
        if (l.isNotEmpty || k.isNotEmpty) names['${e.key}'] = {'l': l, 'k': k};
      }
      for (final e in ((j['chars'] as Map?) ?? const {}).entries) {
        chars['${e.key}'] = Map<String, dynamic>.from(e.value as Map);
      }
      custom = [for (final c in (j['custom'] as List? ?? const [])) CustomChar.fromJson(c as Map)];
    } catch (_) {}
  }

  static Map<String, dynamic> toJson() => {
        'names': names,
        'chars': chars,
        'custom': [for (final c in custom) c.toJson()],
      };

  /// ل دەستپێکا ئەپێ (بەری ناڤەرۆکێ)
  static Future<void> load() async {
    try {
      _parse(await Backend.instance.contentOverride('cast', fresh: false).timeout(const Duration(seconds: 5)));
    } catch (_) {}
  }

  static Future<void> refresh() async => _parse(await Backend.instance.contentOverride('cast'));

  static Future<String?> save() async {
    final err = await Backend.instance.saveContent('cast', toJson());
    if (err == null) changed.value++;
    return err;
  }

  // ───────────── ناڤێن ناڤ رستان ─────────────

  static bool get hasRenames => names.isNotEmpty;

  static String latinOf(StoryName s) {
    final v = names[s.id]?['l'] ?? '';
    return v.isEmpty ? s.latin : v;
  }

  static String kuOf(StoryName s) {
    final v = names[s.id]?['k'] ?? '';
    return v.isEmpty ? s.ku : v;
  }

  static bool isFemaleName(String who) {
    for (final s in storyNames) {
      if (s.gender == 'f' && (who == s.latin || who == latinOf(s))) return true;
    }
    return false;
  }

  static const _ar = r'[؀-ۿݐ-ݿ‌]';
  static bool _endsVowel(String s) => s.isNotEmpty && 'اەۆێیوە'.contains(s[s.length - 1]);

  static List<(RegExp, String)> _kuRules(String old, String neu) {
    final ov = _endsVowel(old), nv = _endsVowel(neu);
    final out = <(RegExp, String)>[];
    void add(String so, String sn) => out.add((RegExp('(?<!$_ar)${RegExp.escape(old + so)}(?!$_ar)'), neu + sn));
    if (ov && !nv) {
      add('یە', 'ە');
      add('مە', 'م');
      add('یێ', 'ێ');
    } else if (!ov && nv) {
      add('ە', 'یە');
      add('م', 'مە');
      add('ێ', 'یێ');
    }
    add('', '');
    // پاشگرێن دی ب ناڤی ڤە: سەفینە، سەفینێ، سەفینی …
    out.add((RegExp('(?<!$_ar)${RegExp.escape(old)}(?=(ە|م|ێ|ی|مە|ن)(?!$_ar))'), neu));
    return out;
  }

  /// ناڤەرۆکا JSON ب ناڤێن نوو — تنێ ئەگەر ئەدمینی ناڤەک گوهۆڕیبیت
  static String text(String raw) {
    if (names.isEmpty) return raw;
    try {
      final renamed = [for (final s in storyNames) if (names.containsKey(s.id)) s];
      if (renamed.isEmpty) return raw;
      final data = jsonDecode(raw);
      return jsonEncode(_walk(data, const {}, renamed, null));
    } catch (_) {
      return raw;
    }
  }

  static Iterable<StoryName> _present(String s, List<StoryName> list) =>
      list.where((n) => RegExp('\\b${RegExp.escape(n.latin)}(?=s?\\b)').hasMatch(s) ||
          (n.kuLat != n.latin && RegExp('\\b${RegExp.escape(n.kuLat)}\\b').hasMatch(s)));

  static Object? _walk(Object? o, Set<String> ctx, List<StoryName> list, String? key) {
    if (o is Map) {
      final here = {...ctx};
      for (final v in o.values) {
        if (v is String) here.addAll(_present(v, list).map((n) => n.id));
        if (v is List) {
          for (final x in v) {
            if (x is String) here.addAll(_present(x, list).map((n) => n.id));
          }
        }
      }
      return {for (final e in o.entries) e.key: _walk(e.value, here, list, '${e.key}')};
    }
    if (o is List) return [for (final x in o) _walk(x, ctx, list, key)];
    if (o is String) return renameIn(o, list: list, ctx: ctx, kuLat: key == 'kuLat');
    return o;
  }

  /// ناڤێن نوو د ئێک رستەیێ دا (لاتینی هەردەم؛ کوردی تنێ ئەگەر ناڤێ لاتینی ل نێزیک بیت)
  static String renameIn(String s, {List<StoryName>? list, Set<String> ctx = const {}, bool kuLat = false}) {
    list ??= [for (final n in storyNames) if (names.containsKey(n.id)) n];
    if (list.isEmpty) return s;
    final here = {...ctx, ..._present(s, list).map((n) => n.id)};
    var out = s;
    for (final n in list) {
      final l = latinOf(n);
      out = out.replaceAll(RegExp('\\b${RegExp.escape(n.latin)}(?=s?\\b)'), l);
      if (n.kuLat != n.latin) out = out.replaceAll(RegExp('\\b${RegExp.escape(n.kuLat)}\\b'), l);
      if (here.contains(n.id) && kuOf(n) != n.ku) {
        for (final (r, rep) in _kuRules(n.ku, kuOf(n))) {
          out = out.replaceAll(r, rep);
        }
      }
    }
    return out;
  }

  // ───────────── کاراکتەرێن 3D ─────────────

  static String? nameOverride(String id) {
    final n = '${chars[id]?['n'] ?? ''}'.trim();
    return n.isEmpty ? null : n;
  }

  static bool hidden(String id) => chars[id]?['hide'] == true;

  /// وێنەیێن کاراکتەرەکێ ئەپێ کو ئەدمینی گوهۆڕین
  static List<String> overrides(String id) => [for (final k in (chars[id]?['k'] as List? ?? const [])) '$k'];

  static CustomChar? customById(String id) {
    for (final c in custom) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// وێنەیێن کاراکتەرەکێ نوو ژ سێرڤەری (ئێک جار)
  static Future<void> ensureImages(String id) {
    if (images.containsKey(id)) return Future.value();
    return _loading[id] ??= () async {
      final m = await Backend.instance.contentByPrefix('charimg_${id}_');
      final out = <String, Uint8List>{};
      for (final e in m.entries) {
        final kind = e.key.substring('charimg_${id}_'.length);
        final v = e.value;
        if (v is String && v.isNotEmpty) {
          try {
            out[kind] = base64Decode(v.contains(',') ? v.substring(v.indexOf(',') + 1) : v);
          } catch (_) {}
        }
      }
      images[id] = out;
      _loading.remove(id);
      changed.value++;
    }();
  }

  /// وێنەیێ کاراکتەرەکێ نوو — ئەگەر نەبیت: یێ نێزیکترین (base …)
  static Uint8List? imageOf(String id, String kind) {
    final m = images[id];
    if (m == null) {
      unawaited(ensureImages(id));
      return null;
    }
    if (m[kind] != null) return m[kind];
    for (final k in _fallback[kind] ?? const ['base']) {
      if (m[k] != null) return m[k];
    }
    for (final v in m.values) {
      return v;
    }
    return null;
  }
}

/// 🖼️ وێنەیێ ڤالا (١×١ ڕۆهن) دەمێ وێنە هێشتا نەگەهشتین
final Uint8List kTransparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

/// ImageProvider بۆ هەر کاراکتەرەکی: یێ ئەپێ (asset)، یێ گوهۆڕی ژ لایێ ئەدمینی، یان یێ نوو
ImageProvider castImage(String id, bool custom, String kind) {
  final asset = 'assets/mascot/${id}_$kind.webp';
  if (custom) return MemoryImage(CastStore.imageOf(id, kind) ?? kTransparentPng);
  final over = CastStore.overrides(id);
  if (over.isEmpty) return AssetImage(asset);
  final m = CastStore.images[id];
  if (m == null) {
    unawaited(CastStore.ensureImages(id));
    return AssetImage(asset);
  }
  return m[kind] != null ? MemoryImage(m[kind]!) : AssetImage(asset);
}
