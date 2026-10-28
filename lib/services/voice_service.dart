import 'dart:io';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models.dart';

/// ژێدەرێ دەنگێ پەیڤەکێ
enum VoiceSource { mine, cloned, pack, tts, none }

/// سیستەمێ دەنگی. رێزا گرنگیێ بۆ هەر پەیڤەکێ:
///   ١. mine   — دەنگێ تە یێ ب دەست تۆمارکری (ستۆدیۆ)
///   ٢. cloned — دەنگێ تە یێ کلۆنکری ژ سێرڤەری (documents/cloned/)
///   ٣. pack   — پاکێتا دەنگێ کلۆنکری ژ Colab (assets/voices/)
///   ٤. tts    — دەنگێ ئۆتۆماتیک (تنێ ئەلمانی/ئینگلیزی)
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  late Directory _voiceDir;
  late Directory clonedDir;
  late Directory referenceDir;
  Set<String> _packAssets = {};
  bool _ready = false;
  String? _recordingPath;

  bool get isRecording => _recordingPath != null;

  Future<void> init() async {
    if (_ready) return;
    final docs = await getApplicationDocumentsDirectory();
    _voiceDir = await Directory('${docs.path}/voices').create(recursive: true);
    clonedDir = await Directory('${docs.path}/cloned').create(recursive: true);
    referenceDir = await Directory('${docs.path}/reference').create(recursive: true);
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _packAssets = manifest.listAssets().where((a) => a.startsWith('assets/voices/')).toSet();
    } catch (_) {
      _packAssets = {};
    }
    await _tts.setSpeechRate(0.42);
    _ready = true;
  }

  // ───────── رێڕەو ─────────
  String pathFor(AppLanguage lang, String id) => '${_voiceDir.path}/${lang.code}_$id.m4a';
  String clonedPathFor(AppLanguage lang, String id) => '${clonedDir.path}/${lang.code}_$id.mp3';
  String _packAsset(AppLanguage lang, String id) => 'assets/voices/${lang.code}_$id.mp3';
  String referencePath(AppLanguage lang) => '${referenceDir.path}/ref_${lang.code}.m4a';
  String get _practicePath => '${_voiceDir.path}/_practice.m4a';
  String? get practiceRecording => File(_practicePath).existsSync() ? _practicePath : null;

  bool hasRecording(AppLanguage lang, String id) => File(pathFor(lang, id)).existsSync();
  bool hasCloned(AppLanguage lang, String id) => File(clonedPathFor(lang, id)).existsSync();
  bool hasReference(AppLanguage lang) => File(referencePath(lang)).existsSync();

  VoiceSource sourceFor(WordConcept c, AppLanguage lang) {
    if (hasRecording(lang, c.id)) return VoiceSource.mine;
    if (hasCloned(lang, c.id)) return VoiceSource.cloned;
    if (_packAssets.contains(_packAsset(lang, c.id))) return VoiceSource.pack;
    if (lang.ttsCode != null) return VoiceSource.tts;
    return VoiceSource.none;
  }

  bool canSpeak(WordConcept c, AppLanguage lang) => sourceFor(c, lang) != VoiceSource.none;

  /// ئەگەر پەیڤ ب دەنگێ تە هەبیت (تۆمار، کلۆن، یان پاکێت)
  bool inMyVoice(WordConcept c, AppLanguage lang) {
    final s = sourceFor(c, lang);
    return s == VoiceSource.mine || s == VoiceSource.cloned || s == VoiceSource.pack;
  }

  int countRecordings(AppLanguage lang, Iterable<WordConcept> cs) => cs.where((c) => hasRecording(lang, c.id)).length;
  int countMyVoice(AppLanguage lang, Iterable<WordConcept> cs) => cs.where((c) => inMyVoice(c, lang)).length;

  // ───────── تۆمارکرن ─────────
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// [path] ئەگەر هاتە دان، تۆمار دێ ل وێرێ پاشەکەفت بیت (بۆ نموونەیا کلۆنکرنێ)
  Future<bool> startRecording({AppLanguage? lang, String? conceptId, bool practice = false, String? path}) async {
    await init();
    if (!await _recorder.hasPermission()) return false;
    await stopPlayback();
    final target = path ?? (practice ? _practicePath : pathFor(lang!, conceptId!));
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100, numChannels: 1),
      path: '$target.tmp.m4a',
    );
    _recordingPath = target;
    return true;
  }

  Future<String?> stopRecording() async {
    final target = _recordingPath;
    _recordingPath = null;
    final tmp = await _recorder.stop();
    if (target == null || tmp == null) return null;
    final tmpFile = File(tmp);
    if (!await tmpFile.exists() || await tmpFile.length() < 2000) {
      if (await tmpFile.exists()) await tmpFile.delete();
      return null;
    }
    final dest = File(target);
    if (await dest.exists()) await dest.delete();
    await tmpFile.rename(target);
    return target;
  }

  Future<void> cancelRecording() async {
    _recordingPath = null;
    await _recorder.cancel();
  }

  Future<void> deleteRecording(AppLanguage lang, String id) async {
    final f = File(pathFor(lang, id));
    if (await f.exists()) await f.delete();
  }

  Future<void> deleteAllCloned() async {
    if (await clonedDir.exists()) {
      await clonedDir.delete(recursive: true);
      await clonedDir.create(recursive: true);
    }
  }

  /// هاوردەکرنا voice_pack.zip ژ Colab راستەوخۆ ل سەر مۆبایلێ (بێ build).
  /// فایلان دکەتە documents/cloned/ و ژمارا فایلێن هاوردەکری دزڤڕینیت.
  Future<int> importPack(String zipPath) async {
    await init();
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    // تنێ ناڤێن وەکی ku_g1.mp3 — پاراستن ژ رێڕەوێن خەلەت
    final valid = RegExp(r'^(ku|de|en)_[A-Za-z0-9_]+\.mp3$');
    var count = 0;
    for (final f in archive) {
      if (!f.isFile) continue;
      final name = f.name.split('/').last;
      if (!valid.hasMatch(name)) continue;
      await File('${clonedDir.path}/$name').writeAsBytes(f.content as List<int>);
      count++;
    }
    return count;
  }

  Stream<Amplitude> amplitudeStream() => _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  // ───────── لێدان ─────────
  Future<bool> speak(WordConcept c, AppLanguage lang, {double rate = 1.0}) async {
    await init();
    await stopPlayback();
    switch (sourceFor(c, lang)) {
      case VoiceSource.mine:
        return _playDevice(pathFor(lang, c.id), rate);
      case VoiceSource.cloned:
        return _playDevice(clonedPathFor(lang, c.id), rate);
      case VoiceSource.pack:
        await _player.setPlaybackRate(rate);
        // AssetSource پێشگرا 'assets/' ب خۆ زێدە دکەت
        await _player.play(AssetSource(_packAsset(lang, c.id).substring('assets/'.length)));
        return true;
      case VoiceSource.tts:
        await _tts.setLanguage(lang.ttsCode!);
        await _tts.setSpeechRate(0.42 * rate);
        await _tts.speak(c.text(lang).replaceAll('...', ''));
        return true;
      case VoiceSource.none:
        return false;
    }
  }

  Future<bool> _playDevice(String path, double rate) async {
    await _player.setPlaybackRate(rate);
    await _player.play(DeviceFileSource(path));
    return true;
  }

  Future<void> playFile(String path) async {
    await stopPlayback();
    await _player.setPlaybackRate(1.0);
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    await _tts.stop();
  }
}
