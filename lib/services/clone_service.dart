import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/curriculum.dart';
import '../models.dart';
import 'voice_service.dart';

/// دەقێن کو بەکارهێنەر بۆ نموونەیا دەنگی دخوینیت.
/// هەمان دەق د voice_lab/voice_core.py دانە — ئەگەر گوهۆڕین، هەردووان بگوهۆڕە.
const referenceScripts = <AppLanguage, String>{
  AppLanguage.badini:
      'سلاڤ، ئەڤە دەنگێ منە. ئەز ب کوردی دئاخڤم و ئەز دێ ئەلمانی و ئینگلیزی فێر بم. ئەڤرۆ هەوا خۆشە و ئەز زۆر کەیفخۆشم.',
  AppLanguage.german: 'Hallo, das ist meine Stimme. Ich lerne jeden Tag ein bisschen Deutsch, und das macht mir Spaß.',
  AppLanguage.english: 'Hello, this is my voice. I am learning English a little every day, and I really enjoy it.',
};

class CloneException implements Exception {
  final String message;
  CloneException(this.message);
  @override
  String toString() => message;
}

/// پەیوەندی دگەل voice_lab/server.py:
/// نموونەیا دەنگێ تە فرێ دکەت و هەمی پەیڤان ب دەنگێ تە ب سێ زمانان دادگریت.
class CloneService {
  CloneService._();
  static final CloneService instance = CloneService._();

  String serverUrl = '';
  String token = '';
  String? speakerId;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    serverUrl = p.getString('clone_url') ?? '';
    token = p.getString('clone_token') ?? '';
    speakerId = p.getString('clone_speaker');
  }

  Future<void> saveSettings(String url, String tok) async {
    serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    token = tok.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString('clone_url', serverUrl);
    await p.setString('clone_token', token);
  }

  Map<String, String> get _headers => {if (token.isNotEmpty) 'X-Token': token};

  Uri _u(String path) {
    if (serverUrl.isEmpty) throw CloneException('Server URL');
    return Uri.parse('$serverUrl$path');
  }

  Future<bool> ping() async {
    try {
      final r = await http.get(_u('/health')).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// فرێکرنا نموونەیێن دەنگی (بادینی پێدڤییە، ئەلمانی/ئینگلیزی ئارەزوومەندانەنە)
  Future<String> uploadReferences() async {
    final v = VoiceService.instance;
    if (!v.hasReference(AppLanguage.badini)) throw CloneException('No Badini reference');
    final req = http.MultipartRequest('POST', _u('/speakers'))
      ..headers.addAll(_headers)
      ..fields['consent'] = 'true';
    for (final lang in AppLanguage.values) {
      if (!v.hasReference(lang)) continue;
      req.files.add(await http.MultipartFile.fromPath('ref_${lang.code}', v.referencePath(lang), filename: 'ref_${lang.code}.m4a'));
      req.fields['ref_text_${lang.code}'] = referenceScripts[lang]!;
    }
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(minutes: 2)));
    if (res.statusCode != 200) throw CloneException('Upload failed (${res.statusCode}): ${res.body}');
    final id = (jsonDecode(res.body) as Map<String, dynamic>)['speaker_id'] as String;
    speakerId = id;
    final p = await SharedPreferences.getInstance();
    await p.setString('clone_speaker', id);
    return id;
  }

  /// دروستکرنا دەنگێ پەیڤەکێ و پاشەکەفتکرن ل مۆبایلێ
  Future<void> synthesize(WordConcept c, AppLanguage lang) async {
    if (speakerId == null) throw CloneException('No speaker');
    final res = await http
        .post(_u('/tts'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'speaker_id': speakerId, 'lang': lang.code, 'text': c.text(lang)}))
        .timeout(const Duration(minutes: 2));
    if (res.statusCode != 200) throw CloneException('TTS failed (${res.statusCode})');
    await File(VoiceService.instance.clonedPathFor(lang, c.id)).writeAsBytes(res.bodyBytes);
  }

  /// هەمی وانەیان ب دەنگێ تە دروست بکە. [onProgress] (done, total)
  Future<int> generateAll({
    required void Function(int done, int total, String label) onProgress,
    bool Function()? isCancelled,
    Set<AppLanguage> langs = const {AppLanguage.badini, AppLanguage.german, AppLanguage.english},
  }) async {
    final v = VoiceService.instance;
    final jobs = [
      for (final lang in langs)
        for (final c in allConcepts)
          if (!v.hasCloned(lang, c.id)) (c, lang),
    ];
    var done = 0;
    var failed = 0;
    var succeeded = 0;
    for (final (c, lang) in jobs) {
      if (isCancelled?.call() ?? false) break;
      onProgress(done, jobs.length, '${lang.flag} ${c.text(lang)}');
      try {
        await synthesize(c, lang);
        succeeded++;
      } catch (_) {
        failed++;
        // ئەگەر ٣ ئێکەمین هەمی سەرنەکەفتن، سێرڤەر کار ناکەت ➔ راوەستە
        if (failed >= 3 && succeeded == 0) rethrow;
      }
      done++;
    }
    onProgress(done, jobs.length, '');
    return failed;
  }

  Future<void> deleteFromServer() async {
    final id = speakerId;
    if (id != null && serverUrl.isNotEmpty) {
      try {
        await http.delete(_u('/speakers/$id'), headers: _headers).timeout(const Duration(seconds: 20));
      } catch (_) {}
    }
    speakerId = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('clone_speaker');
  }
}
