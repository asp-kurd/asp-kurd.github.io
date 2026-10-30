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
PIPER = {
    "de": ("de/de_DE/thorsten/high/de_DE-thorsten-high", 1.0),
    "en": ("en/en_US/lessac/high/en_US-lessac-high", 1.0),
}
HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main/"


def fnv(text: str) -> str:
    h = 0x811C9DC5
    for b in text.encode("utf-8"):
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    return f"{h:08x}"


def collect():
    """{lang: {text_key_source: synth_text}}"""
    cur = json.loads((ROOT / "assets/curriculum.json").read_text(encoding="utf-8"))
    jobs = {"de": {}, "en": {}, "ku": {}}
    for u in cur["units"]:
        for c in u["concepts"]:
            jobs["de"][c["de"]] = c["de"]
            jobs["en"][c["en"]] = c["en"]
            jobs["ku"][c["ku"]] = c["kuLat"]  # کلیل: نڤیسینا کوردی؛ دەنگ: لاتینی
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
    return jobs


def clean(t: str) -> str:
    t = t.replace("...", " ").replace("…", " ").replace("___", " ").replace(" / ", ", ").replace("–", ",")
    return " ".join(t.split())


def to_mp3(wav_path: str, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                    "-af", "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-16",
                    "-ac", "1", "-ar", "24000", "-codec:a", "libmp3lame", "-b:a", "48k", str(dst)], check=True)


def piper_voice(lang):
    from piper import PiperVoice  # noqa
    name, _ = PIPER[lang]
    MODELS.mkdir(parents=True, exist_ok=True)
    onnx = MODELS / (Path(name).name + ".onnx")
    for ext in (".onnx", ".onnx.json"):
        p = MODELS / (Path(name).name + ext)
        if not p.exists():
            subprocess.run(["curl", "-sSfL", "-o", str(p), HF + name + ext], check=True)
    return PiperVoice.load(str(onnx))


def piper_say(voice, text, wav_path):
    with wave.open(wav_path, "wb") as wf:
        if hasattr(voice, "synthesize_wav"):  # piper-tts >= 1.3
            voice.synthesize_wav(text, wf)
        else:
            voice.synthesize(text, wf)


def mms_model():
    import torch  # noqa
    from transformers import AutoTokenizer, VitsModel
    name = "facebook/mms-tts-kmr-script_latin"
    return AutoTokenizer.from_pretrained(name), VitsModel.from_pretrained(name)


def mms_say(model, text, wav_path):
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
        todo = {k: v for k, v in jobs[lang].items() if not (OUT / lang / f"{fnv(k)}.mp3").exists() and clean(v)}
        print(f"[{lang}] {len(jobs[lang])} texts, {len(todo)} missing", flush=True)
        if not todo:
            continue
        engine = piper_voice(lang) if lang in PIPER else mms_model()
        say = piper_say if lang in PIPER else mms_say
        for i, (key, text) in enumerate(todo.items(), 1):
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as t:
                tmp = t.name
            try:
                say(engine, clean(text), tmp)
                to_mp3(tmp, OUT / lang / f"{fnv(key)}.mp3")
                total_new += 1
            except Exception as e:  # ئێک دەنگ سەرنەکەفت: بەردەوام بە
                print(f"  ! {lang} {text[:40]!r}: {e}", flush=True)
            finally:
                os.unlink(tmp)
            if i % 50 == 0:
                print(f"  {lang} {i}/{len(todo)}", flush=True)
    print(f"done: {total_new} new files")


if __name__ == "__main__":
    main()
