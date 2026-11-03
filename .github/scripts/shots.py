"""وێنەگرتنا شاشەیێن تاقیکرنێ (?demo=...) ب Playwright — بۆ پشکنینا دیزاینێ ل تاری و رۆهنی."""
import os, time
from playwright.sync_api import sync_playwright

out = "/tmp/shots"
os.makedirs(out, exist_ok=True)
pages = [
    ("home_light", "demo=home&theme=light"), ("home_dark", "demo=home&theme=dark"),
    ("lesson_light", "demo=lesson&theme=light"), ("summary_light", "demo=summary&theme=light"),
    ("card_light", "demo=card&theme=light"), ("card_dark", "demo=card&theme=dark"),
    ("mascot", "demo=mascot"),
]
with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    for name, q in pages:
        pg = b.new_page(viewport={"width": 428, "height": 926}, device_scale_factor=2)
        try:
            pg.goto(f"http://127.0.0.1:8080/?{q}", wait_until="networkidle", timeout=60000)
            time.sleep(9)
            pg.screenshot(path=f"{out}/{name}.png")
            if name.startswith("lesson"):
                # بەرسڤەکێ هەلبژێرە و پشکنین بکە
                pg.mouse.click(214, 600); time.sleep(0.6)
                pg.mouse.click(214, 860); time.sleep(1.2)
                pg.screenshot(path=f"{out}/{name}_2.png")
        except Exception as e:
            print("fail", name, e)
        pg.close()
    b.close()
print("shots ok")
