import 'dart:convert';

/// 🌳 قۆناغێن دارێ — ئەدمین دشێت ناڤ و XP بگوهۆڕیت (content key: 'tree')
class TreeStage {
  final int xp;
  final String emoji, ku, de, en;
  const TreeStage(this.xp, this.emoji, this.ku, this.de, this.en);

  Map<String, dynamic> toJson() => {'xp': xp, 'emoji': emoji, 'ku': ku, 'de': de, 'en': en};
  static TreeStage fromJson(Map<String, dynamic> j) => TreeStage((j['xp'] as num).toInt(), '${j['emoji'] ?? '🌳'}',
      '${j['ku'] ?? ''}', '${j['de'] ?? j['ku'] ?? ''}', '${j['en'] ?? j['ku'] ?? ''}');
}

const defaultTreeStages = [
  TreeStage(0, '🌰', 'تۆڤ', 'Samen', 'Seed'),
  TreeStage(20, '🌱', 'شینبوون', 'Keimling', 'Sprout'),
  TreeStage(60, '🌿', 'رووەکێ بچووک', 'Kleine Pflanze', 'Small Plant'),
  TreeStage(150, '🪴', 'نەمام', 'Setzling', 'Sapling'),
  TreeStage(300, '🌳', 'دارا گەنج', 'Junger Baum', 'Young Tree'),
  TreeStage(600, '🌳', 'دار', 'Baum', 'Tree'),
  TreeStage(1200, '🌲', 'دارا مەزن', 'Großer Baum', 'Big Tree'),
  TreeStage(2500, '🍎', 'دارا بەردار', 'Fruchtbaum', 'Fruit Tree'),
];

List<TreeStage> treeStages = defaultTreeStages;

/// ناڤەرۆکا ئەدمینی (JSON) ➔ قۆناغێن دارێ. ئەگەر خراب بیت، یێن ئەسلی دمینن.
void loadTree(String? raw) {
  if (raw == null) return;
  try {
    final list = (jsonDecode(raw) as List).map((e) => TreeStage.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.xp.compareTo(b.xp));
    if (list.length >= 2) treeStages = list;
  } catch (_) {}
}
