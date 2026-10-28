"""
سێرڤەرێ کلۆنکرنا دەنگی بۆ ئەپێ ZimanPro.

    pip install fastapi uvicorn python-multipart
    ZIMAN_TOKEN=mysecret uvicorn server:app --host 0.0.0.0 --port 8000

ئەپ:
  1. POST /speakers   ➔ نموونەیا دەنگی فرێ دکەت، speaker_id وەردگریت
  2. POST /tts        ➔ بۆ هەر پەیڤەکێ mp3 ب دەنگێ تە وەردگریت (cache دبیت)

پاراستن: ئەگەر ZIMAN_TOKEN هاتبیتە دانان، هەر داخوازەک دڤێت سەرێ X-Token هەبیت.
"""
import json
import os
import uuid
from pathlib import Path

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel

from voice_core import (REFERENCE_SCRIPTS, Reference, VoiceCloner, cache_key, clean_text,
                        pick_reference, to_wav24k, wav_to_mp3)

DATA = Path(os.environ.get("ZIMAN_DATA", "ziman_data"))
SPEAKERS = DATA / "speakers"
CACHE = DATA / "cache"
SPEAKERS.mkdir(parents=True, exist_ok=True)
CACHE.mkdir(parents=True, exist_ok=True)
TOKEN = os.environ.get("ZIMAN_TOKEN")
MAX_UPLOAD = 15 * 1024 * 1024  # 15MB

app = FastAPI(title="ZimanPro Voice Lab")
cloner = VoiceCloner()


def auth(x_token: str | None = Header(default=None)):
    if TOKEN and x_token != TOKEN:
        raise HTTPException(401, "bad token")


def load_refs(speaker_id: str) -> dict[str, Reference]:
    if not speaker_id.replace("-", "").isalnum():
        raise HTTPException(400, "bad speaker id")
    meta = SPEAKERS / speaker_id / "meta.json"
    if not meta.exists():
        raise HTTPException(404, "speaker not found")
    m = json.loads(meta.read_text(encoding="utf-8"))
    return {lang: Reference(str(SPEAKERS / speaker_id / f"ref_{lang}.wav"), text)
            for lang, text in m["texts"].items()}


@app.get("/health")
def health():
    return {"ok": True}


async def _save(upload: UploadFile, dst: Path):
    data = await upload.read()
    if len(data) > MAX_UPLOAD:
        raise HTTPException(413, "file too large")
    dst.write_bytes(data)


@app.post("/speakers", dependencies=[Depends(auth)])
async def create_speaker(
    consent: bool = Form(...),
    ref_ku: UploadFile = File(...),
    ref_text_ku: str = Form(REFERENCE_SCRIPTS["ku"]),
    ref_de: UploadFile | None = File(None),
    ref_text_de: str = Form(REFERENCE_SCRIPTS["de"]),
    ref_en: UploadFile | None = File(None),
    ref_text_en: str = Form(REFERENCE_SCRIPTS["en"]),
):
    # تنێ دەنگێ خۆ — نە دەنگێ کەسەکێ دی بێ دەستووری
    if not consent:
        raise HTTPException(400, "consent required: only clone your own voice")
    sid = str(uuid.uuid4())
    folder = SPEAKERS / sid
    folder.mkdir(parents=True)
    texts = {}
    for lang, up, text in (("ku", ref_ku, ref_text_ku), ("de", ref_de, ref_text_de), ("en", ref_en, ref_text_en)):
        if up is None:
            continue
        raw = folder / f"raw_{lang}"
        await _save(up, raw)
        to_wav24k(str(raw), str(folder / f"ref_{lang}.wav"))
        raw.unlink()
        texts[lang] = text
    (folder / "meta.json").write_text(json.dumps({"texts": texts}, ensure_ascii=False), encoding="utf-8")
    return {"speaker_id": sid, "langs": list(texts)}


class TtsRequest(BaseModel):
    speaker_id: str
    lang: str  # ku | de | en
    text: str


@app.post("/tts", dependencies=[Depends(auth)])
def tts(req: TtsRequest):
    if req.lang not in ("ku", "de", "en"):
        raise HTTPException(400, "lang must be ku, de or en")
    text = clean_text(req.text)
    if not text or len(text) > 300:
        raise HTTPException(400, "text empty or too long")
    refs = load_refs(req.speaker_id)
    dst = CACHE / f"{cache_key(req.speaker_id, req.lang, text)}.mp3"
    if not dst.exists():
        audio = cloner.synthesize(text, req.lang, pick_reference(req.lang, refs))
        wav_to_mp3(audio, str(dst))
    return FileResponse(dst, media_type="audio/mpeg")


@app.delete("/speakers/{speaker_id}", dependencies=[Depends(auth)])
def delete_speaker(speaker_id: str):
    """ژێبرنا دەنگێ تە ژ سێرڤەری"""
    load_refs(speaker_id)
    import shutil
    shutil.rmtree(SPEAKERS / speaker_id)
    return {"deleted": speaker_id}
