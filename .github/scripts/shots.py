"""وێنەگرتنا شاشەیێن تاقیکرنێ (?demo=...) ب Playwright — بۆ پشکنینا دیزاینێ ل تاری و رۆهنی."""
import os, time
from playwright.sync_api import sync_playwright

out = "/tmp/shots"
os.makedirs(out, exist_ok=True)
pages = [
    ("home_light", "demo=home&theme=light"), ("home_dark", "demo=home&theme=dark"),
    ("lesson_light", "demo=cloze&theme=light"), ("lesson_dark", "demo=cloze&theme=dark"), ("summary_light", "demo=summary&theme=light"),
    ("card_light", "demo=card&theme=light"), ("card_dark", "demo=card&theme=dark"),
    ("pick_light", "demo=pick&theme=light"), ("pick_dark", "demo=pick&theme=dark"), ("mascot", "demo=mascot"), ("grammar_light", "demo=grammar&theme=light"), ("grammar_dark", "demo=grammar&theme=dark"), ("grammar_list", "demo=grammarlist"), ("book", "demo=book"), ("letters", "demo=letters"), ("article", "demo=article"), ("conj", "demo=conj"), ("goethe", "demo=goethe"), ("games", "demo=games&theme=light"), ("gram4", "demo=gram4"), ("gpractice", "demo=gpractice"),
    ("streak", "demo=streak"), ("toast", "demo=toast"), ("combo15", "demo=combo"), ("combo10", "demo=combo10"),
]
with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    for name, q in pages:
        pg = b.new_page(viewport={"width": 428, "height": 926}, device_scale_factor=2)
        logs = []
        pg.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
        pg.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
        try:
            pg.goto(f"http://127.0.0.1:8080/?{q}", wait_until="networkidle", timeout=60000)
            time.sleep(9)
            pg.screenshot(path=f"{out}/{name}.png")
            if name == "toast":
                for k in range(16):
                    time.sleep(0.8); pg.screenshot(path=f"{out}/{name}_{k:02d}.png")
            if name == "streak":
                for k in range(4):
                    time.sleep(0.5); pg.screenshot(path=f"{out}/{name}_{k}.png")
            if name.startswith("combo"):
                time.sleep(0.3); pg.screenshot(path=f"{out}/{name}_b.png")
            if name.startswith("lesson") or name.startswith("combo"):
                # بەرسڤەکێ هەلبژێرە و پشکنین بکە
                for y in (560, 640, 720):
                    pg.mouse.click(214, y); time.sleep(0.4)
                pg.mouse.click(214, 880); time.sleep(0.35)
                pg.screenshot(path=f"{out}/{name}_2.png")
                time.sleep(0.5); pg.screenshot(path=f"{out}/{name}_3.png")
                time.sleep(0.6); pg.screenshot(path=f"{out}/{name}_4.png")
        except Exception as e:
            print("fail", name, e)
        # بۆ هەر خەلەتیەکێ: کۆدێ دۆرا وێ ژ main.dart.js
        import re
        js = open("build/web/main.dart.js", encoding="utf-8").read().split("\n")
        for ln in list(dict.fromkeys(int(m.group(1)) for m in re.finditer(r"main\.dart\.js\?v=\w+:(\d+):\d+", "\n".join(logs))))[:3]:
            logs.append(f"----- main.dart.js:{ln}")
            logs.extend(f"{k+1}: {js[k][:300]}" for k in range(max(0, ln - 40), min(len(js), ln + 3)))
        open(f"{out}/{name}.log", "w").write("\n".join(logs))
        pg.close()
    b.close()
print("shots ok")
