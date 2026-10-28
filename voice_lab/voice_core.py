"""
ZimanPro Voice Lab — ناڤەندا کلۆنکرنا دەنگی

ب نموونەیەکا کورت ژ دەنگێ تە (~١٠–٢٠ چرکە)، هەمی پەیڤێن وانەیان ب دەنگێ تە
ب سێ زمانان دروست دکەت:
  - ku  (بادینی)  ➔ Dezheen89/omnivoice-badini  (fine-tune ل سەر بادینی)
  - de / en        ➔ k2-fsa/OmniVoice            (مۆدێلێ گشتی، 600+ زمان)

پێدڤی ب GPU (NVIDIA) یە — Google Colab یا بێ پارە (T4) بەسە.
تێبینی: مۆدێلێ OmniVoice ب لیسانسا CC-BY-NC یە (بۆ بکارئینانا نە-بازرگانی).
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf

SAMPLE_RATE = 24000
BASE_MODEL = os.environ.get("ZIMAN_BASE_MODEL", "k2-fsa/OmniVoice")
BADINI_MODEL = os.environ.get("ZIMAN_BADINI_MODEL", "Dezheen89/omnivoice-badini")

# دەقێن نموونە کو بەکارهێنەر دخوینیت (هەمان دەق د ئەپی دا هەنە)
REFERENCE_SCRIPTS = {
    "ku": "سلاڤ، ئەڤە دەنگێ منە. ئەز ب کوردی دئاخڤم و ئەز دێ ئەلمانی و ئینگلیزی فێر بم. ئەڤرۆ هەوا خۆشە و ئەز زۆر کەیفخۆشم.",
    "de": "Hallo, das ist meine Stimme. Ich lerne jeden Tag ein bisschen Deutsch, und das macht mir Spaß.",
    "en": "Hello, this is my voice. I am learning English a little every day, and I really enjoy it.",
}


@dataclass
class Reference:
    """نموونەیا دەنگی + دەقێ وێ"""
    audio_path: str
    text: str


def to_wav24k(src: str, dst: str) -> str:
    """هەر فایلەکێ دەنگی (m4a, mp3, ogg, wav...) دکەتە WAV 24kHz mono و بێدەنگیێ ژێ دبەت"""
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", src,
         "-af", "silenceremove=start_periods=1:start_threshold=-45dB:"
                "stop_periods=-1:stop_duration=0.6:stop_threshold=-45dB,loudnorm",
         "-ac", "1", "-ar", str(SAMPLE_RATE), dst],
        check=True,
    )
    return dst


def wav_to_mp3(samples: np.ndarray, dst: str) -> str:
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        sf.write(tmp.name, samples, SAMPLE_RATE)
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
             "-af", "loudnorm", "-codec:a", "libmp3lame", "-q:a", "4", dst],
            check=True,
        )
    finally:
        os.unlink(tmp.name)
    return dst


class VoiceCloner:
    """دوو مۆدێلان ب شێوەیەکێ تەمبەل (lazy) بار دکەت"""

    def __init__(self, device: str = "cuda:0"):
        self.device = device
        self._models: dict[str, object] = {}

    def _model(self, lang: str):
        name = BADINI_MODEL if lang == "ku" else BASE_MODEL
        if name not in self._models:
            import torch
            from omnivoice import OmniVoice

            print(f"⏳ Loading {name} ...")
            self._models[name] = OmniVoice.from_pretrained(
                name, device_map=self.device, dtype=torch.float16
            )
        return self._models[name]

    def synthesize(self, text: str, lang: str, ref: Reference) -> np.ndarray:
        model = self._model(lang)
        kwargs = dict(text=text, ref_audio=ref.audio_path, ref_text=ref.text)
        if lang == "ku":
            # مۆدێلێ بادینی کۆدێ زمانێ kmr ب کار دئینیت
            try:
                out = model.generate(language="kmr", **kwargs)
            except TypeError:
                out = model.generate(**kwargs)
        else:
            out = model.generate(**kwargs)
        audio = out[0] if isinstance(out, (list, tuple)) else out
        return np.asarray(audio, dtype=np.float32)


def pick_reference(lang: str, refs: dict[str, Reference]) -> Reference:
    """ئەگەر نموونە ب هەمان زمانی هەبیت باشترە، دەنا نموونەیا بادینی (cross-lingual)"""
    return refs.get(lang) or refs["ku"]


def cache_key(speaker: str, lang: str, text: str) -> str:
    return hashlib.sha1(f"{speaker}|{lang}|{text}".encode()).hexdigest()[:16]


def clean_text(text: str) -> str:
    # نیشانێن «...» بۆ TTS ب کار نائێن
    return text.replace("...", " ").strip()


def build_pack(curriculum: dict, refs: dict[str, Reference], out_dir: Path,
               cloner: VoiceCloner, langs=("ku", "de", "en"), skip_existing=True) -> int:
    """هەمی پەیڤان دروست دکەت ➔ out_dir/{lang}_{id}.mp3"""
    out_dir.mkdir(parents=True, exist_ok=True)
    field = {"ku": "ku", "de": "de", "en": "en"}
    concepts = [c for u in curriculum["units"] for c in u["concepts"]]
    done = 0
    total = len(concepts) * len(langs)
    for lang in langs:
        ref = pick_reference(lang, refs)
        for c in concepts:
            dst = out_dir / f"{lang}_{c['id']}.mp3"
            done += 1
            if skip_existing and dst.exists():
                continue
            text = clean_text(c[field[lang]])
            audio = cloner.synthesize(text, lang, ref)
            wav_to_mp3(audio, str(dst))
            print(f"[{done}/{total}] {dst.name}  ←  {text}")
    return done
