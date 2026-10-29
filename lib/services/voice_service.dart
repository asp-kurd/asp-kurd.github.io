import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:record/record.dart';

import '../models.dart';
import 'audio_out_native.dart' if (dart.library.js_interop) 'audio_out_web.dart';

/// ژێدەرێ دەنگێ پەیڤەکێ
enum VoiceSource { mine, cloned, pack, tts, none }

/// سیستەمێ دەنگی — ل سەر iPhone (Safari/وێب) و Android ژی کار دکەت.
///
/// هەمی دەنگ وەکی bytes د Hive دا (IndexedDB ل وێبێ) پاشەکەفت دبن، نە وەکی فایل.
/// «path» / «key» ل ڤێرێ ناڤێ تۆمارێیە د Hive دا، بۆ نموونە `mine/ku_g1`.
///
/// رێزا گرنگیێ بۆ هەر پەیڤەکێ:
///   ١. mine   — دەنگێ تە یێ ب دەست تۆمارکری
///   ٢. cloned — دەنگێ تە یێ کلۆنکری (ژ سێرڤەری یان voice_pack.zip)
///   ٣. pack   — assets/voices/ (د ناڤ ئەپی دا)
///   ٤. tts    — دەنگێ ئۆتۆماتیک (ئەلمانی/ئینگلیزی)
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  static const sampleRate = 22050;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioOut _out = AudioOut();
  final FlutterTts _tts = FlutterTts();

  late LazyBox<dynamic> _box;
  Set<String> _packAssets = {};
  final Map<String, Uint8List> _refCache = {}; // بۆ Share ا ب لەز (iOS)
  bool _ready = false;

  // تۆمارکرن
  String? _recordingKey;
  StreamSubscription<Uint8List>? _pcmSub;
  BytesBuilder? _pcm;
  final _levels = StreamController<double>.broadcast();

  bool get isRecording => _recordingKey != null;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter('zimanpro');
    _box = await Hive.openLazyBox<dynamic>('audio');
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _packAssets = manifest.listAssets().where((a) => a.startsWith('assets/voices/')).toSet();
    } catch (_) {
      _packAssets = {};
    }
    for (final l in AppLanguage.values) {
      final b = await _box.get(referencePath(l));
      if (b is Uint8List) _refCache[referencePath(l)] = b;
    }
    _out.installUnlock();
    try {
      await _tts.setSpeechRate(0.42);
    } catch (_) {}
    _ready = true;
  }

  // ───────── کلیل (keys) ─────────
  String pathFor(AppLanguage lang, String id) => 'mine/${lang.code}_$id';
  String clonedPathFor(AppLanguage lang, String id) => 'cloned/${lang.code}_$id';
  String _packAsset(AppLanguage lang, String id) => 'assets/voices/${lang.code}_$id.mp3';
  String referencePath(AppLanguage lang) => 'ref/${lang.code}';
  static const _practiceKey = 'practice';
  String? get practiceRecording => _box.containsKey(_practiceKey) ? _practiceKey : null;

  bool hasRecording(AppLanguage lang, String id) => _box.containsKey(pathFor(lang, id));
  bool hasCloned(AppLanguage lang, String id) => _box.containsKey(clonedPathFor(lang, id));
  bool hasReference(AppLanguage lang) => _refCache.containsKey(referencePath(lang));
  Uint8List? referenceBytes(AppLanguage lang) => _refCache[referencePath(lang)];

  VoiceSource sourceFor(WordConcept c, AppLanguage lang) {
    if (hasRecording(lang, c.id)) return VoiceSource.mine;
    if (hasCloned(lang, c.id)) return VoiceSource.cloned;
    if (_packAssets.contains(_packAsset(lang, c.id))) return VoiceSource.pack;
    if (lang.ttsCode != null) return VoiceSource.tts;
    return VoiceSource.none;
  }

  bool canSpeak(WordConcept c, AppLanguage lang) => sourceFor(c, lang) != VoiceSource.none;

  bool inMyVoice(WordConcept c, AppLanguage lang) {
    final s = sourceFor(c, lang);
    return s == VoiceSource.mine || s == VoiceSource.cloned || s == VoiceSource.pack;
  }

  int countRecordings(AppLanguage lang, Iterable<WordConcept> cs) => cs.where((c) => hasRecording(lang, c.id)).length;
  int countMyVoice(AppLanguage lang, Iterable<WordConcept> cs) => cs.where((c) => inMyVoice(c, lang)).length;

  Future<void> putCloned(AppLanguage lang, String id, Uint8List mp3) => _box.put(clonedPathFor(lang, id), mp3);

  // ───────── تۆمارکرن (PCM ➔ WAV) ─────────
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// [path] = کلیلا پاشەکەفتکرنێ (بۆ نموونە referencePath(lang))
  Future<bool> startRecording({AppLanguage? lang, String? conceptId, bool practice = false, String? path}) async {
    await init();
    if (!await _recorder.hasPermission()) return false;
    await stopPlayback();
    final key = path ?? (practice ? _practiceKey : pathFor(lang!, conceptId!));
    _pcm = BytesBuilder(copy: false);
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
    ));
    _pcmSub = stream.listen((chunk) {
      _pcm?.add(chunk);
      _levels.add(_level(chunk));
    });
    _recordingKey = key;
    return true;
  }

  /// بلندیا دەنگی 0..1 ژ PCM
  double _level(Uint8List chunk) {
    final n = chunk.length ~/ 2;
    if (n == 0) return 0;
    final bd = ByteData.sublistView(chunk);
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final s = bd.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    final rms = math.sqrt(sum / n);
    final db = 20 * math.log(rms + 1e-9) / math.ln10; // -inf..0
    return ((db + 50) / 50).clamp(0.0, 1.0);
  }

  Stream<double> levelStream() => _levels.stream;

  /// راوەستاندن و پاشەکەفتکرن. کلیلێ دزڤڕینیت، یان null ئەگەر تۆمار زۆر کورت بیت.
  Future<String?> stopRecording() async {
    final key = _recordingKey;
    _recordingKey = null;
    await _recorder.stop();
    await Future.delayed(const Duration(milliseconds: 150)); // دویماهیک پارچە
    await _pcmSub?.cancel();
    _pcmSub = null;
    final pcm = _pcm?.takeBytes();
    _pcm = null;
    if (key == null || pcm == null || pcm.length < sampleRate * 2 * 0.3) return null; // < ٠.٣ چرکە
    final wav = _wav(pcm);
    await _box.put(key, wav);
    if (key.startsWith('ref/')) _refCache[key] = wav;
    return key;
  }

  Future<void> cancelRecording() async {
    _recordingKey = null;
    await _recorder.cancel();
    await _pcmSub?.cancel();
    _pcmSub = null;
    _pcm = null;
  }

  Uint8List _wav(Uint8List pcm) {
    const channels = 1, bits = 16;
    final h = ByteData(44);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        h.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    h.setUint32(4, 36 + pcm.length, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little); // PCM
    h.setUint16(22, channels, Endian.little);
    h.setUint32(24, sampleRate, Endian.little);
    h.setUint32(28, sampleRate * channels * bits ~/ 8, Endian.little);
    h.setUint16(32, channels * bits ~/ 8, Endian.little);
    h.setUint16(34, bits, Endian.little);
    str(36, 'data');
    h.setUint32(40, pcm.length, Endian.little);
    return (BytesBuilder(copy: false)
          ..add(h.buffer.asUint8List())
          ..add(pcm))
        .takeBytes();
  }

  Future<void> deleteRecording(AppLanguage lang, String id) => _box.delete(pathFor(lang, id));

  Future<void> deleteAllCloned() async {
    final keys = _box.keys.where((k) => k.toString().startsWith('cloned/')).toList();
    await _box.deleteAll(keys);
  }

  /// هاوردەکرنا voice_pack.zip (ژ Colab). ژمارا دەنگێن هاوردەکری دزڤڕینیت.
  Future<int> importPack(Uint8List zipBytes) async {
    await init();
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final valid = RegExp(r'^(ku|de|en)_([A-Za-z0-9_]+)\.mp3$');
    var count = 0;
    for (final f in archive) {
      if (!f.isFile) continue;
      final m = valid.firstMatch(f.name.split('/').last);
      if (m == null) continue;
      await _box.put('cloned/${m.group(1)}_${m.group(2)}', Uint8List.fromList(f.content as List<int>));
      count++;
    }
    return count;
  }

  // ───────── لێدان ─────────
  Future<bool> speak(WordConcept c, AppLanguage lang, {double rate = 1.0}) async {
    await init();
    await stopPlayback();
    switch (sourceFor(c, lang)) {
      case VoiceSource.mine:
        return _playKey(pathFor(lang, c.id), rate);
      case VoiceSource.cloned:
        return _playKey(clonedPathFor(lang, c.id), rate, mime: 'audio/mpeg');
      case VoiceSource.pack:
        final data = await rootBundle.load(_packAsset(lang, c.id));
        await _out.play(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), rate: rate, mime: 'audio/mpeg');
        return true;
      case VoiceSource.tts:
        try {
          await _tts.setLanguage(lang.ttsCode!);
          await _tts.setSpeechRate(0.42 * rate);
          await _tts.speak(c.text(lang).replaceAll('...', ''));
          return true;
        } catch (_) {
          return false;
        }
      case VoiceSource.none:
        return false;
    }
  }

  /// خواندنا دەقەکێ ئازاد ب TTS (بۆ پەرتووکا رێزمانێ)
  Future<void> speakText(String text, AppLanguage lang) async {
    if (lang.ttsCode == null || text.trim().isEmpty) return;
    await init();
    await stopPlayback();
    try {
      await _tts.setLanguage(lang.ttsCode!);
      await _tts.setSpeechRate(0.42);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<bool> _playKey(String key, double rate, {String mime = 'audio/wav'}) async {
    final b = await _box.get(key);
    if (b is! Uint8List) return false;
    await _out.play(b, rate: rate, mime: mime);
    return true;
  }

  /// لێدانا تۆمارەکێ ب کلیلێ وێ
  Future<void> playFile(String key) async {
    await stopPlayback();
    await _playKey(key, 1.0, mime: key.startsWith('cloned/') ? 'audio/mpeg' : 'audio/wav');
  }

  Future<void> stopPlayback() async {
    await _out.stop();
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
