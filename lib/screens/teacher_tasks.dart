import 'package:flutter/material.dart';

import '../data/curriculum.dart';
import '../models.dart';
import '../services/backend.dart';
import '../services/progress_service.dart';
import '../services/rewards_service.dart';
import '../ui.dart';
import 'lesson_screen.dart';

/// 📌 کارێن مامۆستای (ژ ئەدمینی د ناڤ نامەیان دا):
/// - dinar: دیاری / برینا دیناران (ب خۆ دهێتە ب جهـ ئینان)
/// - quiz: ئەزموونەکا دیاری ژ پەیڤێن هەلبژارتی (+خەلات ئەگەر ٦٠٪+)
/// - assign: دووبارەکرنا قۆناغەکێ (+خەلات پشتی تەمامکرنێ)

/// دیاریێن دیناران ب جهـ بینە (ئێک جار بۆ هەر نامەیەکێ)
void applyAdminGifts() {
  final r = RewardsService.instance;
  for (final m in Backend.instance.messages) {
    final t = AdminTask.parse(m.body);
    if (t == null || t.type != 'dinar' || r.msgDone(m.id)) continue;
    r.applyAdminDinar(m.id, t.amount, m.title);
  }
}

List<(AppMessage, AdminTask)> openTeacherTasks() {
  final r = RewardsService.instance;
  return [
    for (final m in Backend.instance.messages)
      if (AdminTask.parse(m.body) case final t?
          when (t.type == 'quiz' || t.type == 'assign') &&
              !r.msgDone(m.id) &&
              (t.data['lang'] == null || t.data['lang'] == ProgressService.instance.targetLang.code))
        (m, t),
  ];
}

String taskTitle(AdminTask t, AppLanguage n) {
  if (t.type == 'assign') {
    final u = appCurriculum.where((u) => u.id == t.unit).firstOrNull;
    return tr(n, 'دووبارە بخوینە: ${u?.title(n) ?? ''}', 'Wiederhole: ${u?.title(n) ?? ''}', 'Review: ${u?.title(n) ?? ''}');
  }
  return tr(n, 'ئەزموونەکا دیاری 🎁 (${t.ids.length} پرسیار)', 'Geschenk-Quiz 🎁', 'Gift quiz 🎁');
}

void startTeacherTask(BuildContext context, AppMessage m, AdminTask t) {
  final n = ProgressService.instance.nativeLang;
  Backend.instance.markRead(m);
  void done(int percent) {
    if (t.type == 'quiz' && percent < 60) return; // دڤێت ٦٠٪+ بیت
    RewardsService.instance.rewardTask(m.id, t.reward, m.title);
  }

  if (t.type == 'assign') {
    final u = appCurriculum.where((u) => u.id == t.unit).firstOrNull;
    if (u == null) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => InteractiveLessonScreen(unit: u, concepts: u.concepts, onDone: done)));
    return;
  }
  final concepts = [for (final id in t.ids) conceptById(id)].whereType<WordConcept>().toList();
  if (concepts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(n, 'ئەڤ ئەزموونە بۆ زمانەکێ دی یە', 'Anderes Kursziel', 'Different course'))));
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => InteractiveLessonScreen(unit: null, concepts: concepts, onDone: done)));
}

/// کارتێن کارێن مامۆستای ل سەر رێکا فێربوونێ
class TeacherTaskCards extends StatelessWidget {
  const TeacherTaskCards({super.key});

  @override
  Widget build(BuildContext context) {
    final n = ProgressService.instance.nativeLang;
    final tasks = openTeacherTasks();
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final (m, t) in tasks)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6A3DE8), Color(0xFF2B70C9)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Image.asset(t.type == 'quiz' ? 'assets/img/fx/gift.webp' : 'assets/img/vocab/checklist.webp', width: 46, height: 46),
            title: Text('📌 ${taskTitle(t, n)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              [
                if (AdminTask.strip(m.body).isNotEmpty) AdminTask.strip(m.body),
                if (t.reward > 0) tr(n, 'خەلات: ${t.reward} 🪙', 'Belohnung: ${t.reward} 🪙', 'Reward: ${t.reward} 🪙'),
              ].join('\n'),
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
            onTap: () => startTeacherTask(context, m, t),
          ),
        ),
    ]);
  }
}
