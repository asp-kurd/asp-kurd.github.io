import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 🗣️ ناسینا ئاخفتنێ ب Web Speech API (Safari iPhone 14.5+ و Chrome) — بلاش و ل سەر مۆبایلێ
bool get speechSupported => globalContext.has('SpeechRecognition') || globalContext.has('webkitSpeechRecognition');

class SpeechListener {
  JSObject? _rec;

  /// گوهداری دکەت هەتا بکارهێنەر ب دوماهی دئینیت؛ هەمی جۆرێن تێگەهشتنێ ددەتە دەر
  Future<List<String>> listen(String lang, {Duration max = const Duration(seconds: 10)}) {
    final done = Completer<List<String>>();
    final out = <String>[];
    try {
      final ctor = (globalContext.has('SpeechRecognition') ? globalContext['SpeechRecognition'] : globalContext['webkitSpeechRecognition'])
          as JSFunction;
      final rec = ctor.callAsConstructor<JSObject>();
      _rec = rec;
      rec['lang'] = lang.toJS;
      rec['interimResults'] = false.toJS;
      rec['continuous'] = false.toJS;
      rec['maxAlternatives'] = 5.toJS;
      void finish() {
        if (!done.isCompleted) done.complete(out);
      }

      rec['onresult'] = ((JSObject e) {
        final results = e['results'] as JSObject;
        final n = (results['length'] as JSNumber).toDartInt;
        for (var i = 0; i < n; i++) {
          final r = results['$i'] as JSObject;
          final m = (r['length'] as JSNumber).toDartInt;
          for (var j = 0; j < m; j++) {
            final alt = r['$j'] as JSObject;
            final t = (alt['transcript'] as JSString?)?.toDart;
            if (t != null && t.trim().isNotEmpty) out.add(t.trim());
          }
        }
      }).toJS;
      rec['onerror'] = ((JSObject _) => finish()).toJS;
      rec['onend'] = ((JSObject _) => finish()).toJS;
      rec.callMethod('start'.toJS);
      Future.delayed(max, stop);
    } catch (_) {
      if (!done.isCompleted) done.complete(out);
    }
    return done.future;
  }

  void stop() {
    try {
      _rec?.callMethod('stop'.toJS);
    } catch (_) {}
  }
}
