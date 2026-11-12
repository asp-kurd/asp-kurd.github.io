import 'dart:async';

import 'package:flutter/material.dart';

import '../services/backend.dart';
import '../ui.dart';

/// 💬 گفتوگۆیا راستەوخۆ: فێرخواز ⇄ ئەدمین
/// - فێرخواز تنێ نامێن خۆ و بەرسڤێن ئەدمینی دبینیت (کەسێن دی نابینن)
/// - تنێ ئەدمین دشێت نامان ژێببەت (ژ هەردوو لایان)
class ChatScreen extends StatefulWidget {
  /// null = فێرخواز (گفتوگۆیا من)؛ ئەگەر نە: ئەدمین دگەل ڤی فێرخوازی
  final String? learnerId;
  final String? name;
  const ChatScreen({super.key, this.learnerId, this.name});

  bool get admin => learnerId != null;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _Msg {
  final int id;
  final String body;
  final bool fromLearner, read;
  final DateTime at;
  const _Msg(this.id, this.body, this.fromLearner, this.read, this.at);
}

class _ChatScreenState extends State<ChatScreen> {
  final b = Backend.instance;
  final input = TextEditingController();
  final scroll = ScrollController();
  List<_Msg> msgs = [];
  bool loading = true, sending = false;
  String? error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final before = msgs.length;
    try {
      if (widget.admin) {
        final l = await b.adminChat(widget.learnerId!);
        msgs = [
          for (final m in l)
            _Msg((m['id'] as num).toInt(), '${m['body']}', m['from_learner'] == true, m['read_at'] != null,
                DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now()),
        ];
        unawaited(b.adminMarkChatRead(widget.learnerId!));
      } else {
        await b.loadChat();
        msgs = [for (final m in b.chat) _Msg(m.id, m.body, m.fromLearner, m.read, m.created)];
        unawaited(b.markChatRead());
      }
      error = null;
    } catch (e) {
      if (!silent) error = '$e';
    }
    if (!mounted) return;
    setState(() => loading = false);
    if (msgs.length != before) _toEnd();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final t = input.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    final err = widget.admin ? await b.adminSendChat(widget.learnerId!, t) : await b.sendChat(t);
    if (!mounted) return;
    setState(() => sending = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err == 'setup'
              ? 'ئەدمین هێشتا گفتوگۆیێ ڤەنەکرییە — پاشی جارەکا دی تاقی بکە 🙏'
              : 'نامە نەچوو، ئینتەرنێتێ پشکنە ($err)')));
      return;
    }
    input.clear();
    await _load(silent: true);
  }

  Future<void> _delete(_Msg m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('🗑️ ژێبرنا نامێ؟'),
          content: Text(m.body, maxLines: 4, overflow: TextOverflow.ellipsis),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نە')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ژێببە')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await b.deleteMessage(m.id);
    await _load(silent: true);
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('🗑️ هەمی گفتوگۆیێ ژێببە؟'),
          content: Text('هەمی نامێن دناڤبەرا تە و ${widget.name ?? ''} دێ ژ هەردوو لایان هێنە ژێبرن.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نە')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('هەمیان ژێببە')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await b.adminDeleteChat(widget.learnerId!);
    await _load(silent: true);
  }

  String _time(DateTime d) {
    final now = DateTime.now();
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (d.year == now.year && d.month == now.month && d.day == now.day) return hm;
    return '${d.day}/${d.month} · $hm';
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.admin;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.chip,
              backgroundImage: admin ? null : const AssetImage('assets/brand/logo.png'),
              child: admin ? Text((widget.name ?? '?').characters.first) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(admin ? (widget.name ?? '') : 'ئەدمینێ ASP', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(admin ? 'گفتوگۆیا تایبەت' : 'بەرسڤ ب زوویی دهێت', style: TextStyle(fontSize: 12, color: AppColors.fg60)),
              ]),
            ),
          ]),
          actions: [
            if (admin && msgs.isNotEmpty)
              IconButton(tooltip: 'هەمیان ژێببە', icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.red), onPressed: _deleteAll),
          ],
        ),
        body: Column(children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(12)),
            child: Text(
              admin
                  ? '🔒 ئەڤ گفتوگۆیە تنێ د ناڤبەرا تە و ڤی فێرخوازی دایە. بۆ ژێبرنا نامەکێ، تبلا خۆ ل سەر بهێلە.'
                  : '🔒 نامێن تە تنێ بۆ ئەدمینی دیار دبن — کەسەکێ دی نابینیت.',
              style: TextStyle(fontSize: 12, color: AppColors.fg70),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (error != null && msgs.isEmpty)
                    ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(error!)))
                    : msgs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const Text('💬', style: TextStyle(fontSize: 54)),
                                const SizedBox(height: 10),
                                Text(admin ? 'هێشتا چ نامە نینن' : 'پرسیار، پێشنیار یان کێشەیەک هەیە؟\nنامەکێ بۆ ئەدمینی بنڤیسە 👇',
                                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.fg60, height: 1.6)),
                              ]),
                            ),
                          )
                        : ListView.builder(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            itemCount: msgs.length,
                            itemBuilder: (_, i) => _bubble(msgs[i]),
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'نامەیا خۆ بنڤیسە…',
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'send',
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  onPressed: sending ? null : _send,
                  child: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final mine = widget.admin ? !m.fromLearner : m.fromLearner;
    final color = mine ? AppColors.blue : AppColors.card;
    return Align(
      // RTL: یێن من ل لایێ راستێ
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onLongPress: widget.admin ? () => _delete(m) : null,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(18),
              topEnd: const Radius.circular(18),
              bottomStart: Radius.circular(mine ? 4 : 18),
              bottomEnd: Radius.circular(mine ? 18 : 4),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            SelectableText(m.body, style: TextStyle(color: mine ? Colors.white : AppColors.fg, fontSize: 15, height: 1.45)),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_time(m.at), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : AppColors.fg54)),
              if (mine) ...[
                const SizedBox(width: 4),
                Icon(m.read ? Icons.done_all_rounded : Icons.done_rounded, size: 13, color: Colors.white70),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
