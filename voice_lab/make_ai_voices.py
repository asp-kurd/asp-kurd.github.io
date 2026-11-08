"""
دەنگێ AI بۆ هەمی ناڤەرۆکێ ASP — ل GitHub Actions کار دکەت (CPU، بێ GPU).

  ئەلمانی  → Piper  de_DE-thorsten-high   (MIT / CC0)
  ئینگلیزی → Piper  en_US-lessac-high
  بادینی   → Meta MMS-TTS  facebook/mms-tts-kmr-script_latin  (کورمانجی ب پیتێن لاتینی، CC-BY-NC)

فایل: assets/tts/<lang>/<fnv1a32(text)>.mp3 — کلیل ژ دەقێ تەمام دهێتە دروستکرن،
هەمان یێ VoiceService.textKey د Dart دا. تنێ فایلێن کێم دهێنە دروستکرن.
"""
import json, os, subprocess, sys, tempfile, wave
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
OUT = ROOT / "assets" / "tts"
MODELS = Path(os.environ.get("PIPER_DIR", "/tmp/piper"))
# ([مۆدێل، جهگر…], length_scale) — length_scale > 1 = هێدیتر و ئاشکەراتر بۆ فێرخوازان
# فۆلدەر: de = 👨 (thorsten)، de_f = 👩؛ en = 👩 (lessac)، en_m = 👨
PIPER = {
    "de": (["de/de_DE/thorsten/high/de_DE-thorsten-high"], 1.22),
    "de_f": (["de/de_DE/kerstin/low/de_DE-kerstin-low", "de/de_DE/ramona/low/de_DE-ramona-low"], 1.18),
    "en": (["en/en_US/lessac/high/en_US-lessac-high"], 1.15),
    "en_m": (["en/en_US/ryan/high/en_US-ryan-high", "en/en_US/joe/medium/en_US-joe-medium"], 1.15),
}
SAME_TEXT = {"de_f": "de", "en_m": "en"}  # هەمان دەق، دەنگەکێ دی
MMS_RATE = 0.72  # بادینی: هێدیتر و ئارامتر
# دەمێ شێوازێ دەنگی دگوهۆڕیت، ڤێ ژمارێ زێدە بکە دا هەمی دەنگ ژ نوو بهێنە دروستکرن (بۆ هەر فۆلدەرەکی ب جودا)
VOICE_VERSION = {"de": "2-slow-clear", "en": "2-slow-clear", "ku": "3-slower", "de_f": "1", "en_m": "1"}
HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main/"


# ناڤێ پیتان وەکی دهێنە خواندن (دا AI «A» وەکی پیت بخوینیت، نە وەکی پەیڤ)
LETTER_NAMES = {
    "de": dict(A="A", B="Be", C="Ze", D="De", E="E", F="Eff", G="Ge", H="Ha", I="I", J="Jott", K="Ka", L="El", M="Em",
               N="En", O="O", P="Pe", Q="Ku", R="Er", S="Es", T="Te", U="U", V="Fau", W="We", X="Ix", Y="Ypsilon",
               Z="Zett", **{"Ä": "Ä", "Ö": "Ö", "Ü": "Ü", "ß": "Eszett"}),
    "en": dict(A="ay", B="bee", C="see", D="dee", E="ee", F="eff", G="gee", H="aitch", I="eye", J="jay", K="kay",
               L="el", M="em", N="en", O="oh", P="pee", Q="queue", R="are", S="ess", T="tee", U="you", V="vee",
               W="double you", X="ex", Y="why", Z="zee"),
}


def fnv(text: str) -> str:
    h = 0x811C9DC5
    for b in text.encode("utf-8"):
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    return f"{h:08x}"


def collect():
    """{lang: {text_key_source: synth_text}}"""
    cur = json.loads((ROOT / "assets/curriculum.json").read_text(encoding="utf-8"))
    jobs = {"de": {}, "en": {}, "ku": {}, "de_f": {}, "en_m": {}}
    for u in cur["units"]:
        only = u.get("only")  # قۆناغێن تایبەت ب زمانەکی (ئەلفوبێ)
        for c in u["concepts"]:
            if only in (None, "de"):
                jobs["de"][c["de"]] = c["de"]
            if only in (None, "en"):
                jobs["en"][c["en"]] = c["en"]
            if only in (None, "ku"):
                jobs["ku"][c["ku"]] = c["kuLat"]  # کلیل: نڤیسینا کوردی؛ دەنگ: لاتینی
            lt = c.get("letter")  # 🔤 ناڤێ پیتێ ب تنێ (C ➔ «تسێ»)
            if lt and only in ("de", "en"):
                jobs[only][lt["L"]] = LETTER_NAMES[only].get(lt["L"], lt["L"])
            cz = c.get("cloze")
            if cz:  # رستا تەمام یا «جهێ ڤالا»
                full = cz["de"]
                for part in cz["a"].split(" … "):
                    full = full.replace("___", part, 1)
                jobs["de"][full] = full
    for l in cur.get("lektionen", []):
        for line in l["dialog"]["lines"]:
            jobs["de"][line["de"]] = line["de"]
    ex = ROOT / "assets/exams.json"
    if ex.exists():
        e = json.loads(ex.read_text(encoding="utf-8"))
        qs = [q for v in e["lektion"].values() for q in v] + [q for p in e["final"]["parts"] for q in p["items"]] + e["placement"]
        for q in qs:
            if q.get("audio"):
                jobs["de"][q["audio"]] = q["audio"]
    summ = ROOT / "assets/a1_summary.json"
    if summ.exists():  # ⚡ A1 mit Poya: رستێن نموونە
        for c in json.loads(summ.read_text(encoding="utf-8"))["cards"]:
            for e in c["examples"]:
                jobs["de"][e["de"]] = e["de"]
    gram = ROOT / "assets/grammar.json"
    if gram.exists():  # 📘 رێزمان ل دویف وانێ: نموونە
        for l in json.loads(gram.read_text(encoding="utf-8"))["lektionen"]:
            for t in l["topics"]:
                for e in t["examples"]:
                    jobs["de"][e["de"]] = e["de"]
                for pr in t.get("practice", []):  # 🎯 راهێنان: پرسیار + بەرسڤ
                    for k in ("q", "a"):
                        txt = pr[k]
                        if "→" not in txt and ":" not in txt and "(" not in txt and "___" not in txt:
                            jobs["de"][txt] = txt
    goe = ROOT / "assets/goethe.json"
    if goe.exists():  # 🎓 Goethe Modelltest: دەنگێ گوهداریێ (ب ڕەگەزێ ئاخفتنکەری)
        for part in json.loads(goe.read_text(encoding="utf-8"))["parts"]:
            for sec in part["sections"]:
                for it in sec["items"]:
                    for ln in it.get("audio") or []:
                        key = "de_f" if ln["g"] == "f" else "de"
                        jobs[key][ln["t"]] = ln["t"]
                    for c in it.get("cards") or []:
                        if isinstance(c, dict) and c.get("ex"):
                            jobs["de"][c["ex"]] = c["ex"]
                    if it.get("example"):
                        jobs["de"][it["example"]] = it["example"]
    kom = ROOT / "assets/kommunikation.json"
    if kom.exists():  # 💬 Kommunikation ژ پەرتووکێ
        for l in json.loads(kom.read_text(encoding="utf-8"))["lektionen"]:
            for g in l["groups"]:
                for ln in g["lines"]:
                    if "…" not in ln["de"]:
                        jobs["de"][ln["de"]] = ln["de"]
    book = ROOT / "assets/book.json"
    if book.exists():
        def walk(o):
            if isinstance(o, dict):
                for k, v in o.items():
                    if k in ("de", "speak") and isinstance(v, str) and 0 < len(v) < 160:
                        jobs["de"][v] = v
                    walk(v)
            elif isinstance(o, list):
                for v in o:
                    walk(v)
        walk(json.loads(book.read_text(encoding="utf-8")))
    for k, src in SAME_TEXT.items():
        jobs[k] = {**jobs[src], **jobs[k]}
    return jobs


def clean(t: str) -> str:
    t = t.replace("...", " ").replace("…", " ").replace("___", " ").replace(" / ", ", ").replace("–", ",")
    return " ".join(t.split())


def to_mp3(wav_path: str, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                    "-af", "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
                    # بێدەنگیەکا کورت ل دەستپێکێ دا ئێکەم پیت نەهێتە بڕین (iPhone)
                    "loudnorm=I=-16:TP=-1.5,adelay=150:all=1,apad=pad_dur=0.25",
                    "-ac", "1", "-ar", "24000", "-codec:a", "libmp3lame", "-b:a", "64k", str(dst)], check=True)


def piper_voice(lang):
    from piper import PiperVoice  # noqa
    names, _ = PIPER[lang]
    MODELS.mkdir(parents=True, exist_ok=True)
    for name in names:  # ئەگەر مۆدێلەک نەبیت، یێ دی تاقی بکە
        onnx = MODELS / (Path(name).name + ".onnx")
        try:
            for ext in (".onnx", ".onnx.json"):
                p = MODELS / (Path(name).name + ext)
                if not p.exists():
                    subprocess.run(["curl", "-sSfL", "-o", str(p), HF + name + ext], check=True)
            print(f"[{lang}] model {Path(name).name}", flush=True)
            return PiperVoice.load(str(onnx))
        except Exception as e:
            print(f"[{lang}] ! {name}: {e}", flush=True)
            for ext in (".onnx", ".onnx.json"):
                (MODELS / (Path(name).name + ext)).unlink(missing_ok=True)
    raise RuntimeError(f"no model for {lang}")


def piper_say(voice, text, wav_path, length_scale=1.0):
    with wave.open(wav_path, "wb") as wf:
        if hasattr(voice, "synthesize_wav"):  # piper-tts >= 1.3
            try:
                from piper import SynthesisConfig
                cfg = SynthesisConfig(length_scale=length_scale, noise_scale=0.55, noise_w_scale=0.7)
                voice.synthesize_wav(text, wf, syn_config=cfg)
            except ImportError:
                voice.synthesize_wav(text, wf)
        else:
            voice.synthesize(text, wf, length_scale=length_scale, noise_scale=0.55, noise_w=0.7, sentence_silence=0.35)


def mms_model():
    import torch  # noqa
    from transformers import AutoTokenizer, VitsModel
    name = "facebook/mms-tts-kmr-script_latin"
    m = VitsModel.from_pretrained(name)
    m.speaking_rate = MMS_RATE
    m.noise_scale = 0.55
    return AutoTokenizer.from_pretrained(name), m


def mms_say(model, text, wav_path, _scale=1.0):
    import numpy as np, torch, soundfile as sf
    tok, m = model
    inputs = tok(text.lower(), return_tensors="pt")
    with torch.no_grad():
        audio = m(**inputs).waveform[0].numpy()
    sf.write(wav_path, np.asarray(audio, dtype=np.float32), m.config.sampling_rate)


def main():
    jobs = collect()
    only = os.environ.get("LANGS", "de,en,ku").split(",")
    total_new = 0
    for lang in only:
        vfile = OUT / lang / ".version"
        if not vfile.exists() or vfile.read_text().strip() != VOICE_VERSION[lang]:
            # شێوازێ دەنگی هاتە گوهۆڕین ➔ هەمی فایلێن کەڤن ژێببە
            removed = 0
            for f in (OUT / lang).glob("*.mp3"):
                f.unlink(); removed += 1
            print(f"[{lang}] voice style changed → regenerating all ({removed} old files removed)", flush=True)
        todo = {k: v for k, v in jobs[lang].items() if not (OUT / lang / f"{fnv(k)}.mp3").exists() and clean(v)}
        print(f"[{lang}] {len(jobs[lang])} texts, {len(todo)} missing", flush=True)
        if not todo:
            continue
        engine = piper_voice(lang) if lang in PIPER else mms_model()
        say = piper_say if lang in PIPER else mms_say
        scale = PIPER[lang][1] if lang in PIPER else 1.0
        for i, (key, text) in enumerate(todo.items(), 1):
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as t:
                tmp = t.name
            try:
                say(engine, clean(text), tmp, scale)
                to_mp3(tmp, OUT / lang / f"{fnv(key)}.mp3")
                total_new += 1
            except Exception as e:  # ئێک دەنگ سەرنەکەفت: بەردەوام بە
                print(f"  ! {lang} {text[:40]!r}: {e}", flush=True)
            finally:
                os.unlink(tmp)
            if i % 50 == 0:
                print(f"  {lang} {i}/{len(todo)}", flush=True)
        (OUT / lang).mkdir(parents=True, exist_ok=True)
        vfile.write_text(VOICE_VERSION[lang])
    print(f"done: {total_new} new files")


if __name__ == "__main__":
    main()
