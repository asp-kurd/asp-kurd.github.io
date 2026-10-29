"""پەرتووکا رێزمانێ (Markdown) دگوهۆڕیت بۆ assets/book.json کو ئەپ دخوینیت.

بکارئینان:
    python voice_lab/build_book.py book/A1_mit_Poya.md assets/book.json

جۆرێن بلۆکان د JSON دا:
  h      سەرناڤێ بچووک          {"t":"h","text":...}
  p      پاراگراف (**bold** دمینیت) {"t":"p","text":...}
  ul/ol  لیست                    {"t":"ul","items":[...]}
  table  خشتە                    {"t":"table","head":[...],"rows":[[...]]}
  vocab  فەرهەنگۆک ب رەنگێ رەگەزی {"t":"vocab","gender":"der","items":[[de,ku],...]}
  quiz   راهێنانا ب بەرسڤا ڤەشارتی {"t":"quiz","items":[{"q":...,"a":...}],"why":...}
"""
import json
import re
import sys

# بەش ← پشک (part) و ئایکۆن
PARTS = [
    {"id": 0, "ku": "دەستپێک", "de": "Einstieg", "en": "Start"},
    {"id": 1, "ku": "پشکا ١: بنیات", "de": "Teil 1: Grundlagen", "en": "Part 1: Basics"},
    {"id": 2, "ku": "پشکا ٢: ناڤ و ئارتیکل", "de": "Teil 2: Nomen und Artikel", "en": "Part 2: Nouns & articles"},
    {"id": 3, "ku": "پشکا ٣: حالەتێن رێزمانی", "de": "Teil 3: Die Fälle", "en": "Part 3: Cases"},
    {"id": 4, "ku": "پشکا ٤: دەم", "de": "Teil 4: Zeit und Zeitformen", "en": "Part 4: Time & tenses"},
    {"id": 5, "ku": "پشکا ٥: پراکتیک", "de": "Teil 5: Praxis", "en": "Part 5: Practice"},
]
# ل دویڤ رێزا بەشان د Markdown دا: (پشک، ئایکۆن، رەنگ)
CHAPTER_META = [
    (0, "flag", "#1CB0F6"),       # پێشەکی
    (1, "abc", "#58CC02"),        # ١ ئەلفوبێ
    (1, "waving_hand", "#58CC02"),
    (1, "badge", "#58CC02"),
    (1, "pin", "#58CC02"),
    (1, "person", "#58CC02"),
    (1, "help", "#58CC02"),       # ٦
    (2, "article", "#CE82FF"),    # ٧
    (2, "family", "#CE82FF"),     # ٨
    (3, "looks_one", "#FF9600"),  # ٩
    (3, "looks_two", "#FF9600"),  # ١٠
    (3, "looks_3", "#FF9600"),    # ١١
    (3, "swap", "#FF9600"),       # ١٢
    (3, "call_split", "#FF9600"), # ١٣
    (4, "schedule", "#FF4B4B"),   # ١٤
    (4, "history", "#FF4B4B"),    # ١٥
    (4, "update", "#FF4B4B"),     # ١٦
    (5, "chat", "#1CB0F6"),       # ١٧
    (5, "menu_book", "#FFC800"),  # فەرهەنگۆک
    (5, "quiz", "#FFC800"),       # راهێنان
]

_ESC = re.compile(r"\\([\\`*_{}\[\]()#+\-.!~|>])")


def clean(s: str) -> str:
    return _ESC.sub(r"\1", s).strip()


def cells(line: str):
    return [clean(c) for c in line.strip().strip("|").split("|")]


def parse(md: str):
    lines = md.splitlines()
    chapters, ch, i = [], None, 0
    while i < len(lines):
        line = lines[i].rstrip()
        if line.startswith("## "):
            ch = {"title": clean(line[3:]), "blocks": []}
            chapters.append(ch)
        elif ch is None or not line.strip():
            pass
        elif line.startswith("### "):
            ch["blocks"].append({"t": "h", "text": clean(line[4:])})
        elif line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                if not re.match(r"^\|\s*-{3}", lines[i]):
                    rows.append(cells(lines[i]))
                i += 1
            ch["blocks"].append({"t": "table", "head": rows[0], "rows": rows[1:]})
            continue
        elif re.match(r"^\s*(- |\d+\. )", line):
            ordered = bool(re.match(r"^\s*\d+\. ", line))
            items = []
            while i < len(lines) and re.match(r"^\s*(- |\d+\. )", lines[i]):
                items.append(clean(re.sub(r"^\s*(- |\d+\. )", "", lines[i])))
                i += 1
            ch["blocks"].append({"t": "ol" if ordered else "ul", "items": items})
            continue
        else:
            ch["blocks"].append({"t": "p", "text": clean(line)})
        i += 1
    return chapters


def to_vocab(ch):
    """خشتێن ٤ ستوونی یێن فەرهەنگۆکێ دکەتە کارتێن رەنگکری."""
    out = []
    for b in ch["blocks"]:
        if b["t"] == "table" and b["head"][:2] == ["ئەلمانی", "بادینی"] and len(b["head"]) == 4 and len(b["rows"]) > 40:
            gender = b["rows"][0][0].split()[0]
            left = [[r[0], r[1]] for r in b["rows"]]
            right = [[r[2], r[3]] for r in b["rows"]]
            out.append({"t": "vocab", "gender": gender, "items": left + right})
        else:
            out.append(b)
    ch["blocks"] = out


def to_quiz(ch):
    """لیستێن راهێنانان + خشتەیا بەرسڤان ➔ پرسیارێن ب بەرسڤا ڤەشارتی."""
    blocks = ch["blocks"]
    answers = next(b for b in blocks if b["t"] == "table" and b["head"][0] == "راهێنان")
    keyed = []
    for row in answers["rows"]:
        parts = re.split(r"\s*·\s*", row[1])
        keyed.append(([re.sub(r"^\d+\s+", "", p) for p in parts], row[2]))
    out, n = [], 0
    for b in blocks:
        if b is answers:
            continue
        if b["t"] == "ol" and n < len(keyed):
            ans, why = keyed[n]
            out.append({"t": "quiz", "items": [{"q": q, "a": a} for q, a in zip(b["items"], ans)], "why": why})
            n += 1
        elif b["t"] == "h" and b["text"] == "بەرسڤ":
            continue
        else:
            out.append(b)
    ch["blocks"] = out


def main(src, dst):
    md = open(src, encoding="utf-8").read()
    chapters = parse(md)
    assert len(chapters) == len(CHAPTER_META), f"{len(chapters)} بەش، {len(CHAPTER_META)} meta"
    result = []
    for idx, (ch, (part, icon, color)) in enumerate(zip(chapters, CHAPTER_META)):
        if "فەرهەنگۆکا" in ch["title"]:
            to_vocab(ch)
        if ch["title"].startswith("راهێنان"):
            to_quiz(ch)
        result.append({"id": f"ch{idx}", "part": part, "icon": icon, "color": color, **ch})
    data = {"version": 1, "title": "A1.1 mit Poya", "parts": PARTS, "chapters": result}
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(f"{len(result)} بەش ➔ {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
