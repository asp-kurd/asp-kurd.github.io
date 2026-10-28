"""
دروستکرنا پاکێتا دەنگی ب دەنگێ تە بۆ هەمی وانەیان.

    python generate_pack.py --ref-ku my_voice_ku.m4a
    python generate_pack.py --ref-ku ku.m4a --ref-de de.m4a --ref-en en.m4a

ئەنجام: voice_pack.zip ➔ ڤەکە د ناڤ zimanpro/assets/voices/ دا و ئەپی ژ نوو build بکە.
ئەگەر تە دەقەکێ دی خواند (نە دەقێ نموونە)، ب --ref-text-ku بنڤیسە.
"""
import argparse
import json
import shutil
import tempfile
from pathlib import Path

from voice_core import REFERENCE_SCRIPTS, Reference, VoiceCloner, build_pack, to_wav24k

HERE = Path(__file__).parent


def main():
    ap = argparse.ArgumentParser()
    for lang in ("ku", "de", "en"):
        ap.add_argument(f"--ref-{lang}", help=f"نموونەیا دەنگی ب زمانێ {lang}", required=(lang == "ku"))
        ap.add_argument(f"--ref-text-{lang}", default=REFERENCE_SCRIPTS[lang])
    ap.add_argument("--curriculum", default=str(HERE / "curriculum.json"))
    ap.add_argument("--out", default="voice_pack")
    ap.add_argument("--langs", default="ku,de,en")
    args = ap.parse_args()

    work = Path(tempfile.mkdtemp())
    refs = {}
    for lang in ("ku", "de", "en"):
        src = getattr(args, f"ref_{lang}")
        if src:
            wav = to_wav24k(src, str(work / f"ref_{lang}.wav"))
            refs[lang] = Reference(wav, getattr(args, f"ref_text_{lang}"))
            print(f"✅ Reference {lang}: {src}")

    curriculum = json.loads(Path(args.curriculum).read_text(encoding="utf-8"))
    out_dir = Path(args.out)
    build_pack(curriculum, refs, out_dir, VoiceCloner(), langs=tuple(args.langs.split(",")))
    zip_path = shutil.make_archive(str(out_dir), "zip", out_dir)
    print(f"\n🎉 {zip_path}")


if __name__ == "__main__":
    main()
