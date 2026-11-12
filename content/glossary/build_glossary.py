"""📖 فەرهەنگا پەیڤان بۆ «تبلا خۆ ل سەر پەیڤێ بدە» ➔ assets/glossary.json
   ژێدەر: content/glossary/<lang>.tsv (پەیڤ|رامان|تێبینی) + پەیڤێن ئێک-پەیڤی یێن curriculum.json
   python3 content/glossary/build_glossary.py   (راپۆرتا پەیڤێن بێ رامان ژی ددەت)"""
import json, re, collections, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOK = r"[A-Za-zÄÖÜäöüß]+(?:[-'’][A-Za-zÄÖÜäöüß]+)*"
tok = lambda s: re.findall(TOK, s or "")

cur = json.loads((ROOT / "assets/curriculum.json").read_text(encoding="utf-8"))
cs = [c for u in cur["units"] for c in u["concepts"] if "letter" not in c]
cz = json.loads((ROOT / "assets/cloze.json").read_text(encoding="utf-8"))["units"]
ART = {"de": ("der", "die", "das"), "en": ("the", "a", "an", "to")}
out = {}
for lang in ("de", "en"):
    g = {}
    # ١) ژ وانەیان: «der Apfel» / «Apfel» ➔ رامان + ئارتیکل
    for c in cs:
        t = tok(c.get(lang))
        if len(t) == 1:
            g.setdefault(t[0], [c["ku"], ""])
        elif len(t) == 2 and t[0].lower() in ART[lang]:
            g.setdefault(t[1], [c["ku"], t[0].lower() if lang == "de" else ""])
    # ٢) فەرهەنگا دەستی (پێشەنگییا وێ هەیە)
    f = ROOT / f"content/glossary/{lang}.tsv"
    if f.exists():
        for ln in f.read_text(encoding="utf-8").splitlines():
            if not ln.strip() or ln.startswith("#"):
                continue
            p = (ln.split("|") + ["", ""])[:3]
            w, ku, note = (x.strip() for x in p)
            old = g.get(w)
            # ئارتیکلێ وانێ بپارێزە ئەگەر د فەرهەنگێ دا نەبیت
            if old and not note and old[1]:
                note = old[1]
            g[w] = [ku, note]
    out[lang] = g
    # ٣) راپۆرت: هەمی پەیڤێن رستەیان
    sent = []
    for c in cs:
        z = c.get("cloze") if lang == "de" else c.get("clozeEn")
        if z:
            s = z.get(lang) or z.get("s") or ""
            for p in z["a"].split(" … "):
                s = s.replace("___", p, 1)
            sent.append(s)
        if len(tok(c.get(lang))) >= 2:
            sent.append(c[lang])
    for m in cz.values():
        for e in m.get(lang, []):
            s = e["s"]
            for p in e["a"].split(" … "):
                s = s.replace("___", p, 1)
            sent.append(s)
    low = {k.lower() for k in g}
    cnt = collections.Counter(w for s in sent for w in tok(s))
    miss = sorted({w for w in cnt if w not in g and w.lower() not in low})
    tot = sum(cnt.values()); mt = sum(cnt[w] for w in miss)
    print(f"[{lang}] {len(g)} entries · sentences {len(sent)} · tokens {tot} · uncovered {len(miss)} words ({mt} tokens, {100*mt/max(tot,1):.1f}%)")
    if miss and "-v" in sys.argv:
        print("   ", " ".join(miss))

(ROOT / "assets/glossary.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print("assets/glossary.json", (ROOT / "assets/glossary.json").stat().st_size, "bytes")
