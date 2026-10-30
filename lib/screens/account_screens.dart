import 'package:flutter/material.dart';

import '../config.dart';
import '../services/backend.dart';
import '../services/progress_service.dart';
import '../services/push_stub.dart' if (dart.library.js_interop) '../services/push_web.dart';
import '../ui.dart';

// ───────────────────────── 📝 تۆمارکرن ─────────────────────────

/// دەمێ کەسەک بۆ جارا ئێکێ ئەپی ڤەدکەت: ناڤ + تەمەن + جهێ ئاکنجیبوونێ
class RegisterScreen extends StatefulWidget {
  final Widget next;
  const RegisterScreen({super.key, required this.next});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final age = TextEditingController();
  final city = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (name.text.trim().length < 2) {
      setState(() => error = 'تکایە ناڤێ خۆ بنڤیسە');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final p = ProgressService.instance;
    final err = await Backend.instance.register(
      name: name.text,
      age: int.tryParse(age.text.trim()),
      city: city.text,
      native: p.nativeLang.code,
      target: p.targetLang.code,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        busy = false;
        error = 'پەیوەندی سەرنەکەفت. ئینتەرنێتێ پشکنە و دیسا تاقی بکە.\n($err)';
      });
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.next));
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 10),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset('assets/brand/logo.png', width: 110, height: 110),
                ),
              ),
              const SizedBox(height: 18),
              const Text('ب خێر بێی بۆ ASP! 👋',
                  textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Sarchia', fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('بەری دەستپێکرنێ، خۆ بدە ناسین', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 26),
              TextField(controller: name, textInputAction: TextInputAction.next, decoration: _dec('ناڤێ تە', Icons.person_rounded)),
              const SizedBox(height: 14),
              TextField(
                controller: age,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: _dec('تەمەن', Icons.cake_rounded),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: city,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _go(),
                decoration: _dec('جهێ ئاکنجیبوونێ (باژێڕ)', Icons.location_on_rounded),
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(error!, style: const TextStyle(color: AppColors.red)),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.next)),
                  child: const Text('پاشان — بێ هەژمار بەردەوام بە'),
                ),
              ],
              const SizedBox(height: 22),
              busy
                  ? const Center(child: CircularProgressIndicator())
                  : BigButton(label: 'دەستپێبکە', icon: Icons.arrow_back_rounded, onPressed: _go),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 📬 نامە ─────────────────────────

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final b = Backend.instance;

  @override
  void initState() {
    super.initState();
    b.loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('📬 نامەیێن من')),
        body: ListenableBuilder(
          listenable: b,
          builder: (_, __) {
            if (b.messages.isEmpty) {
              return const Center(child: Text('چ نامە نینن', style: TextStyle(color: Colors.white54)));
            }
            return RefreshIndicator(
              onRefresh: b.loadMessages,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                if (pushSupported && pushPermission != 'granted') const NotifyCard(),
                for (final m in b.messages) _tile(m),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(AppMessage m) {
    final icon = switch (m.kind) { 'streak' => '🔥', 'system' => '⚙️', _ => '✉️' };
    return Card(
      color: m.read ? AppColors.card : const Color(0xFF1B3A4B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: m.read ? Colors.white12 : AppColors.gold, width: m.read ? 1 : 2),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: Text(icon, style: const TextStyle(fontSize: 26)),
        title: Text(m.title, style: TextStyle(fontWeight: m.read ? FontWeight.normal : FontWeight.bold)),
        subtitle: Text('ژ ASP · ${_ago(m.created)}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
        onExpansionChanged: (open) {
          if (open) b.markRead(m);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(m.body, style: const TextStyle(fontSize: 16, height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'نوکە';
  if (d.inMinutes < 60) return '${d.inMinutes} خولەک بەری نوکە';
  if (d.inHours < 24) return '${d.inHours} دەمژمێر بەری نوکە';
  if (d.inDays < 30) return '${d.inDays} رۆژ بەری نوکە';
  return '${t.year}/${t.month}/${t.day}';
}

String agoKu(DateTime t) => _ago(t);

/// 🔔 کارتا ڤەکرنا ئاگەهداریان (iPhone: تنێ ژ Home Screen)
class NotifyCard extends StatefulWidget {
  const NotifyCard({super.key});

  @override
  State<NotifyCard> createState() => _NotifyCardState();
}

class _NotifyCardState extends State<NotifyCard> {
  bool busy = false;
  String? msg;

  @override
  Widget build(BuildContext context) {
    if (!Backend.instance.registered) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF1CB0F6)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        const Text('🔔', style: TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ئاگەهداریان ڤەکە', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
            Text(msg ?? 'دا نامە و بیرئینانا Streak بگەهنە تە', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        busy
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                onPressed: () async {
                  setState(() => busy = true);
                  try {
                    final sub = await subscribePush(AppConfig.vapidPublicKey);
                    if (sub != null) {
                      await Backend.instance.savePushSubscription(sub);
                      msg = '✅ ڤەبوو!';
                    } else {
                      msg = 'ل iPhone: ئێکەم ئەپی بکە سەر Home Screen، پاشان ژ وێرێ ڤەکە.';
                    }
                  } catch (e) {
                    msg = 'سەرنەکەفت: $e';
                  }
                  if (mounted) setState(() => busy = false);
                },
                child: const Text('ڤەکە'),
              ),
      ]),
    );
  }
}
