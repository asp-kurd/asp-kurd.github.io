"""🌳 A2 (Schritte international Neu 3–4, Lektion 1–14) ➔ assets/*.json

ناڤەرۆک ب دەستێ مە هاتییە نڤیسین (رستە و دیالۆگێن مە ب خۆ — نە ژ پەرتووکێ)، ل دویف بابەت و ریزبەندیا رێزمانێ یا A2.
فایلێن L01.txt … L14.txt ب ڤی شێوازی:

  @L 15 | #رەنگ | ناڤ کوردی | Titel | Title
  @U a | icon | ناڤێ قۆناغێ | Titel | Title
  de | خواندن | کوردی | english | emoji [| رستە ب ___ | بەرسڤ | خەلەت١; خەلەت٢ | وەرگێڕان]
  @CZ رستە ب ___ … ___ | a … b | d1; d2 | وەرگێڕان
  @D ناڤێ دیالۆگێ
  Who: Deutsch || کوردی
  @G emoji | Titel | ناڤ
  E: ڕوونکرن de || ku     H: سەر | سەر     R: خانە | خانە
  X: نموونە de || ku      T: تێبینی de || ku   P: q || qku || cue || a || aku   M: de || ku

python3 content/a2/build_a2.py
"""
import json
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent
A = ROOT / "assets"

# ───────── خواندنا بادینی ب لاتینی (کورمانجی) ─────────
_cons = {
    "ب": "b", "پ": "p", "ت": "t", "ج": "c", "چ": "ç", "ح": "h", "خ": "x", "د": "d", "ر": "r", "ڕ": "r", "ز": "z",
    "ژ": "j", "س": "s", "ش": "ş", "ع": "'", "غ": "x", "ف": "f", "ڤ": "v", "ق": "q", "ک": "k", "ك": "k", "گ": "g",
    "ل": "l", "ڵ": "l", "م": "m", "ن": "n", "ه": "h", "ھ": "h", "ة": "e", "ئ": "",
}
_vow = {"ا": "a", "ە": "e", "ێ": "ê", "ۆ": "o"}


def ku_lat(s: str) -> str:
    out = []
    i = 0
    while i < len(s):
        ch = s[i]
        prev = s[i - 1] if i > 0 else " "
        nxt = s[i + 1] if i + 1 < len(s) else " "
        word_start = not ("؀" <= prev <= "ۿ")
        if ch == "و":
            if nxt == "و":
                out.append("û")
                i += 2
                continue
            if word_start or prev in _vow or prev == "ئ" or nxt in _vow:
                out.append("w")
            else:
                out.append("u")
        elif ch == "ی":
            if word_start or prev in _vow or prev == "ئ" or nxt in _vow:
                out.append("y")
            else:
                out.append("î")
        elif ch in _vow:
            out.append(_vow[ch])
        elif ch in _cons:
            c = _cons[ch]
            # ئ + کۆنسۆنانت ➔ i (ئەز ➔ ez: ئ بێ دەنگە)
            if ch == "ئ" and nxt not in _vow and nxt not in "وی":
                c = "i"
            out.append(c)
        elif ch == "؟":
            out.append("?")
        elif ch == "،":
            out.append(",")
        else:
            out.append(ch)
        i += 1
    t = "".join(out)
    return t[:1].upper() + t[1:]


def parse(path: Path):
    lek = {"units": [], "dialog": None, "grammar": [], "cz": []}
    unit = None
    gram = None
    for raw in path.read_text(encoding="utf-8").split("\n"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("@L "):
            f = [x.strip() for x in line[3:].split("|")]
            lek.update(n=int(f[0]), color=f[1], ku=f[2], de=f[3], en=f[4])
            continue
        if line.startswith("@U "):
            f = [x.strip() for x in line[3:].split("|")]
            unit = {"key": f[0], "icon": f[1], "ku": f[2], "de": f[3], "en": f[4], "concepts": [], "cz": []}
            lek["units"].append(unit)
            gram = None
            continue
        if line.startswith("@CZ "):
            f = [x.strip() for x in line[4:].split("|")]
            unit["cz"].append({"s": f[0], "a": f[1], "d": [d.strip() for d in f[2].split(";")], "ku": f[3]})
            continue
        if line.startswith("@D "):
            lek["dialog"] = {"titleKu": line[3:].strip(), "lines": []}
            unit = None
            gram = None
            continue
        if line.startswith("@G "):
            f = [x.strip() for x in line[3:].split("|")]
            gram = {"emoji": f[0], "title": {"de": f[1], "ku": f[2]}, "head": [], "rows": [], "examples": [], "practice": [], "more": []}
            lek["grammar"].append(gram)
            unit = None
            continue
        if gram is not None and len(line) > 2 and line[1] == ":" and line[0] in "EHRXTPM":
            k, v = line[0], line[2:].strip()
            if k == "E":
                de, ku = [x.strip() for x in v.split("||")]
                gram["explain"] = {"de": de, "ku": ku}
            elif k == "H":
                gram["head"] = [x.strip() for x in v.split("|")]
            elif k == "R":
                gram["rows"].append([x.strip() for x in v.split("|")])
            elif k in "XM":
                de, ku = [x.strip() for x in v.split("||")]
                gram["examples" if k == "X" else "more"].append({"de": de, "ku": ku})
            elif k == "T":
                de, ku = [x.strip() for x in v.split("||")]
                gram["tip"] = {"de": de, "ku": ku}
            elif k == "P":
                q, qku, cue, a, aku = [x.strip() for x in v.split("||")]
                gram["practice"].append({"q": q, "qku": qku, "cue": cue, "a": a, "aku": aku})
            continue
        if lek["dialog"] is not None and unit is None and gram is None:
            who, rest = line.split(":", 1)
            de, ku = [x.strip() for x in rest.split("||")]
            lek["dialog"]["lines"].append({"who": who.strip(), "de": de, "ku": ku})
            continue
        if unit is not None:
            f = [x.strip() for x in line.split("|")]
            if len(f) < 5:
                raise SystemExit(f"{path.name}: bad line: {line}")
            c = {"de": f[0], "deHint": f[1], "ku": f[2], "en": f[3], "emoji": f[4]}
            if len(f) >= 9 and f[5]:
                c["cloze"] = {"de": f[5], "a": f[6], "d": [d.strip() for d in f[7].split(";")], "ku": f[8]}
                assert "___" in f[5], line
            unit["concepts"].append(c)
    return lek


def main():
    leks = [parse(p) for p in sorted(SRC.glob("L*.txt"))]
    cur = json.loads((A / "curriculum.json").read_text(encoding="utf-8"))
    cur["units"] = [u for u in cur["units"] if not u["id"].startswith("unit_a2_")]
    cur["lektionen"] = [l for l in cur["lektionen"] if l["n"] <= 14]
    cur["sections"] = cur["sections"][:15]
    cur["version"] = max(cur.get("version", 0), 8)
    gram = json.loads((A / "grammar.json").read_text(encoding="utf-8"))
    gram["lektionen"] = [l for l in gram["lektionen"] if l["n"] <= 14]
    komm = json.loads((A / "kommunikation.json").read_text(encoding="utf-8"))
    komm["lektionen"] = [l for l in komm["lektionen"] if l["n"] <= 14]
    ex = json.loads((A / "exams.json").read_text(encoding="utf-8"))
    ex["lektion"] = {k: v for k, v in ex["lektion"].items() if int(k) <= 14}
    cz = json.loads((A / "cloze.json").read_text(encoding="utf-8"))
    cz["units"] = {k: v for k, v in cz["units"].items() if not k.startswith("unit_a2_")}

    total = 0
    for lek in sorted(leks, key=lambda x: x["n"]):
        n = lek["n"]
        a2 = n - 14
        cur["sections"].append({"ku": f"A2 · وانە {to_ku(a2)} · {lek['ku']}", "de": f"A2 · Lektion {a2} · {lek['de']}",
                                "en": f"A2 · Lesson {a2} · {lek['en']}"})
        k = 0
        all_c = []
        for ui, u in enumerate(lek["units"]):
            uid = f"unit_a2_{a2}{u['key']}"
            concepts = []
            for c in u["concepts"]:
                k += 1
                cid = f"b{a2}_{k:02d}"
                item = {"id": cid, "ku": c["ku"], "kuLat": ku_lat(c["ku"]), "de": c["de"], "deHint": c["deHint"],
                        "en": c["en"], "enHint": "", "emoji": c["emoji"]}
                if "cloze" in c:
                    item["cloze"] = c["cloze"]
                concepts.append(item)
                all_c.append(item)
            unit = {"id": uid, "section": n + 1, "only": "de", "icon": u["icon"], "color": lek["color"],
                    "titleKu": u["ku"], "titleDe": u["de"], "titleEn": u["en"], "concepts": concepts}
            g = lek["grammar"][ui] if ui < len(lek["grammar"]) else None
            if g is not None:
                lines = [g["explain"]["ku"]] + [f"{x['de']} — {x['ku']}" for x in g["examples"][:2]]
                unit["grammar"] = {"titleKu": g["title"]["ku"], "titleDe": g["title"]["de"], "lines": lines,
                                   "table": ([g["head"]] + g["rows"]) if g["head"] and g["rows"] else None}
            cur["units"].append(unit)
            if u["cz"]:
                cz["units"][uid] = {"de": [{**e, "c": ""} for e in u["cz"]]}
            total += len(concepts)
        d = lek["dialog"] or {"titleKu": lek["ku"], "lines": []}
        cur["lektionen"].append({
            "n": n, "titleKu": lek["ku"], "titleDe": lek["de"], "titleEn": lek["en"], "color": lek["color"],
            "dialog": {"titleKu": d["titleKu"], "lines": [{"id": f"dl{n}_{i + 1}", **x} for i, x in enumerate(d["lines"])]},
        })
        gram["lektionen"].append({"n": n, "topics": lek["grammar"]})
        # 💬 Kommunikation: رستێن ئامادە ژ هەر قۆناغەکێ
        groups = []
        for u in lek["units"]:
            sents = [c for c in u["concepts"] if len(c["de"].split()) >= 3][:7]
            if len(sents) >= 3:
                groups.append({"emoji": sents[0]["emoji"], "de": u["de"], "ku": u["ku"],
                               "lines": [{"de": c["de"], "ku": c["ku"]} for c in sents]})
        komm["lektionen"].append({"n": n, "groups": groups})
        ex["lektion"][str(n)] = exam(all_c, lek, n)
    for name, obj in (("curriculum", cur), ("grammar", gram), ("kommunikation", komm), ("exams", ex), ("cloze", cz)):
        orig = (A / f"{name}.json").read_text(encoding="utf-8").split("\n")
        ind = (len(orig[1]) - len(orig[1].lstrip(" "))) if len(orig) > 1 else None
        (A / f"{name}.json").write_text(json.dumps(obj, ensure_ascii=False, indent=ind), encoding="utf-8")
    print(f"A2: {len(leks)} Lektionen, {total} concepts")


def to_ku(n: int) -> str:
    return "".join("٠١٢٣٤٥٦٧٨٩"[int(d)] for d in str(n))


def exam(cs, lek, n):
    rng = random.Random(n * 7919)
    q = []
    clz = [c for c in cs if "cloze" in c]
    rng.shuffle(clz)
    for c in clz[:4]:
        opts = [c["cloze"]["a"]] + c["cloze"]["d"][:2]
        rng.shuffle(opts)
        q.append({"type": "choice", "q": c["cloze"]["de"], "options": opts, "answer": opts.index(c["cloze"]["a"]),
                  "explain": c["cloze"]["ku"]})
    sents = [c for c in cs if len(c["de"].split()) >= 3]
    words = [c for c in cs if len(c["de"].split()) <= 3]
    rng.shuffle(sents)
    rng.shuffle(words)
    for c in sents[:2]:
        others = rng.sample([x for x in cs if x is not c], 3)
        opts = [c["ku"]] + [x["ku"] for x in others]
        rng.shuffle(opts)
        q.append({"type": "listen", "q": "🎧", "options": opts, "answer": opts.index(c["ku"]), "explain": c["de"], "audio": c["de"]})
    pics = [c for c in words if c["emoji"]]
    for c in pics[:2]:
        others = rng.sample([x for x in pics if x is not c and x["emoji"] != c["emoji"]], 3)
        opts = [c["emoji"]] + [x["emoji"] for x in others]
        rng.shuffle(opts)
        q.append({"type": "picture", "q": c["de"], "options": opts, "answer": opts.index(c["emoji"]), "explain": c["ku"], "audio": c["de"]})
    short = [c for c in cs if 2 <= len(c["de"].split()) <= 4 and c not in sents[:2]]
    rng.shuffle(short)
    for c in short[:2]:
        q.append({"type": "type", "q": c["ku"], "options": None, "answer": c["de"], "explain": c["deHint"], "pic": c["emoji"]})
    longs = [c for c in sents[2:] if 4 <= len(c["de"].split()) <= 8]
    for c in longs[:2]:
        w = re.sub(r"[.!?]$", "", c["de"]).split()
        sh = w[:]
        while sh == w:
            rng.shuffle(sh)
        q.append({"type": "order", "q": " | ".join(sh), "options": None, "answer": " ".join(w), "explain": c["ku"]})
    for i, c in enumerate(sents[4:6]):
        if i == 0:
            q.append({"type": "truefalse", "q": f"«{c['de']}» = {c['ku']}", "options": ["Richtig", "Falsch"], "answer": 0, "explain": c["ku"]})
        else:
            other = rng.choice([x for x in sents if x is not c])
            q.append({"type": "truefalse", "q": f"«{c['de']}» = {other['ku']}", "options": ["Richtig", "Falsch"], "answer": 1,
                      "explain": c["ku"]})
    rng.shuffle(q)
    return q


if __name__ == "__main__":
    main()
