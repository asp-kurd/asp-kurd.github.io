import 'package:flutter/material.dart';

import '../../models.dart';
import '../../ui.dart';

/// 🎮 جۆرێن یاریان
enum GameKind {
  pickPicture('pick', '🖼️', Color(0xFF1CB0F6), 'وێنەیی هەلبژێرە', 'Bild wählen', 'Pick the Picture',
      'پەیڤێ ببینە، وێنەیی هەلبژێرە', 'Sieh das Wort, wähle das Bild', 'See the word, pick the picture'),
  matchPairs('match', '🧩', Color(0xFFFF4B91), 'جووتان بدۆزە', 'Paare finden', 'Match the Pairs',
      'وێنە و پەیڤان پێکڤە گرێبدە', 'Bilder und Wörter verbinden', 'Match pictures and words'),
  typeWord('type', '⌨️', Color(0xFFCE82FF), 'پەیڤێ بنڤیسە', 'Wort tippen', 'Type the Word',
      'وێنەیی ببینە، پەیڤێ بنڤیسە', 'Sieh das Bild, tippe das Wort', 'See the picture, type the word'),
  finishSentence('finish', '✍️', Color(0xFF58CC02), 'رستێ تەمام بکە', 'Satz ergänzen', 'Finish the Sentence',
      'پەیڤا کێم هەلبژێرە', 'Wähle das fehlende Wort', 'Pick the missing word'),
  dictation('dictation', '🎧', Color(0xFFFF9600), 'دیکتە', 'Diktat', 'Dictation',
      'گوهداری بکە و بنڤیسە', 'Hör zu und schreib es', 'Hear it, type it'),
  wordSearch('search', '🔤', Color(0xFFFFC800), 'پەیڤا ڤەشارتی', 'Wortsuche', 'Word Search',
      'پەیڤێ د ناڤ پیتان دا بدۆزە', 'Finde das Wort im Buchstabensalat', 'Find the word in the letters'),
  shadowing('shadow', '🎙️', Color(0xFF00C2A8), 'دووبارە بکە ب دەنگی', 'Nachsprechen', 'Shadowing',
      'گوهداری بکە، بخوینە، ب دەنگێ بلند بێژە', 'Hören, lesen, laut sagen', 'Listen, read, say it out loud');

  final String id, emoji;
  final Color color;
  final String ku, de, en, subKu, subDe, subEn;
  const GameKind(this.id, this.emoji, this.color, this.ku, this.de, this.en, this.subKu, this.subDe, this.subEn);

  String title(AppLanguage l) => tr(l, ku, de, en);
  String subtitle(AppLanguage l) => tr(l, subKu, subDe, subEn);
}

/// ستێر ل دویڤ خەلەتیان
int starsForMistakes(int mistakes) => mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : 1);

/// ریزەکا ٣ ستێران
class StarRow extends StatelessWidget {
  final int stars;
  final double size;
  const StarRow({super.key, required this.stars, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == 1 ? size * 0.35 : 0, left: 2, right: 2),
          child: Icon(Icons.star_rounded,
              size: i == 1 ? size * 1.15 : size, color: i < stars ? AppColors.gold : Colors.white24),
        ),
    ]);
  }
}
