bool get speechSupported => false;

class SpeechListener {
  Future<List<String>> listen(String lang, {Duration max = const Duration(seconds: 10)}) async => const [];
  void stop() {}
}
