import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backend.dart';
import '../services/voice_backup.dart';
import '../services/voice_service.dart';
import '../ui.dart';

/// 💾 پاشەکەفتکرنا دەنگێن من: ل سەر هەژمارێ (ئیمەیل) و/یان وەکی فایل ل سەر مۆبایلێ
class VoiceBackupScreen extends StatefulWidget {
  const VoiceBackupScreen({super.key});
  @override
  State<VoiceBackupScreen> createState() => _VoiceBackupScreenState();
}

class _VoiceBackupScreenState extends State<VoiceBackupScreen> {
  static const maxCloud = 10 * 1024 * 1024; // ١٠ MB بۆ هەر کەسەکی
  bool busy = false;
  String? msg;
  bool msgOk = true;

  int get count => VoiceService.instance.myRecordingKeys.length;

  String _ku(Object n) => '$n'.split('').map((d) => '0123456789'.contains(d) ? '٠١٢٣٤٥٦٧٨٩'['0123456789'.indexOf(d)] : d).join();

  Future<void> _run(Future<String> Function() job) async {
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      final m = await job();
      if (mounted) setState(() => msg = m);
    } catch (e) {
      if (mounted) {
        setState(() {
          msgOk = false;
          msg = '❌ $e';
        });
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<String> _toCloud() async {
    final (n, zip) = await VoiceBackup.build();
    if (n == 0) return '🎤 هێشتا تە چ دەنگ تۆمار نەکرینە.';
    if (zip.length > maxCloud) {
      msgOk = false;
      return '⚠️ دەنگێن تە ژ ١٠ MB مەزنترن. پاشەکەفتکرنا وەکی فایل ب کار بینە 👇';
    }
    final e = await Backend.instance.uploadVoices(zip);
    msgOk = e == null;
    if (e == null) return '✅ ${_ku(n)} دەنگ ل سەر هەژمارا تە هاتنە پاشەکەفتکرن (${_ku((zip.length / 1024).round())} KB).';
    if (e == '400' || e == '403' || e == '404') return '⏳ ئەڤ پشکە هێشتا ل سەر سێرڤەری نەهاتییە ڤەکرن. نوکە وەکی فایل پاشەکەفت بکە 👇';
    return '❌ سەرنەکەفت ($e). ئینتەرنێتێ بپشکنە و دیسا هەول بدە.';
  }

  Future<String> _fromCloud() async {
    final zip = await Backend.instance.downloadVoices();
    if (zip == null) {
      msgOk = false;
      return '🤷 چ پاشەکەفتکرن ل سەر هەژمارا تە نینە.';
    }
    final n = await VoiceBackup.restore(zip);
    msgOk = true;
    return '✅ ${_ku(n)} دەنگ هاتنە ڤەگەڕاندن.';
  }

  Future<String> _toFile() async {
    final (n, zip) = await VoiceBackup.build();
    if (n == 0) return '🎤 هێشتا تە چ دەنگ تۆمار نەکرینە.';
    await Share.shareXFiles([XFile.fromData(zip, name: 'asp_dengen_min.zip', mimeType: 'application/zip')],
        text: 'ASP — دەنگێن من');
    msgOk = true;
    return '📁 فایل ئامادەیە (${_ku(n)} دەنگ). «Save to Files» هەلبژێرە دا ل سەر مۆبایلێ بمینیت.';
  }

  Future<String> _fromFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip'], withData: true);
    final Uint8List? b = res?.files.single.bytes;
    if (b == null) return '';
    final n = await VoiceBackup.restore(b);
    msgOk = n > 0;
    return n > 0 ? '✅ ${_ku(n)} دەنگ هاتنە ڤەگەڕاندن.' : '❌ ئەڤ فایلە نە یێ دەنگێن ASP یە.';
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.instance;
    final canCloud = b.enabled && b.registered;
    Widget card(String emoji, String title, String sub, List<Widget> buttons) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 6),
            Text(sub, style: TextStyle(color: AppColors.fg60, height: 1.5)),
            const SizedBox(height: 12),
            ...buttons,
          ]),
        );
    Widget btn(String label, IconData icon, Future<String> Function() job, {bool primary = true}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: primary
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: busy ? null : () => _run(job),
                  icon: Icon(icon),
                  label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)))
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: busy ? null : () => _run(job),
                  icon: Icon(icon),
                  label: Text(label)),
        );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('💾 پاشەکەفتکرنا دەنگێن من')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text('🎤 ${_ku(count)} دەنگێن تە تۆمارکرینە ل سەر ڤێ مۆبایلێ هەنە.', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('پاشەکەفت بکە دا ئەگەر مۆبایلا خۆ گوهۆڕی یان Safari پاقژ کەی، دەنگێن تە بەرزە نەبن.', style: TextStyle(color: AppColors.fg60)),
          const SizedBox(height: 16),
          card('☁️', 'ل سەر هەژمارا من', canCloud
              ? 'ب ئیمەیلا خۆ ل هەر مۆبایلەکێ بچە ژوور و دەنگێن خۆ ڤەگەڕینە. (هەتا ١٠ MB)'
              : 'بۆ ڤێ پشکێ دڤێت هەژمارەک هەبیت.', [
            if (canCloud) btn('پاشەکەفتکرن ل سەر هەژمارێ', Icons.cloud_upload_rounded, _toCloud),
            if (canCloud) btn('ڤەگەڕاندن ژ هەژمارێ', Icons.cloud_download_rounded, _fromCloud, primary: false),
          ]),
          card('📁', 'وەکی فایل ل سەر مۆبایلێ', 'فایلەکێ zip دروست دبیت؛ ل iPhone «Save to Files» هەلبژێرە. هەر دەمەکێ دشێی ب ڤی فایلی دەنگان ڤەگەڕینی.', [
            btn('پاشەکەفتکرن وەکی فایل', Icons.save_alt_rounded, _toFile),
            btn('ڤەگەڕاندن ژ فایلێ', Icons.folder_open_rounded, _fromFile, primary: false),
          ]),
          if (busy) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
          if (msg != null && msg!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (msgOk ? AppColors.green : AppColors.red).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(msg!, style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5)),
            ),
        ]),
      ),
    );
  }
}
