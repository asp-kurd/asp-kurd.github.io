"""وێنەگرتنا شاشەیێن تاقیکرنێ (?demo=...) ب Playwright — بۆ پشکنینا دیزاینێ ل تاری و رۆهنی."""
import os, time
from playwright.sync_api import sync_playwright

out = "/tmp/shots"
os.makedirs(out, exist_ok=True)
pages = [
    ("matchgreet", "demo=matchgame&g=1&theme=red"),
]
with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    for name, q in pages:
        ua = ("Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
              if name.startswith("gate_ios") else None)
        pg = b.new_page(viewport={"width": 428, "height": 926}, device_scale_factor=2, **({"user_agent": ua} if ua else {}))
        logs = []
        pg.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
        pg.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
        try:
            if name == "splash":
                # ✨ شاشا دەستپێکێ: وێنە ل دەمێن جودا
                # ⏱️ دەمێ ڤەبوونێ: هەتا ئێکەم وێنێ Flutter و هەتا نەمانا شاشا دەستپێکێ
                pg.add_init_script("window.__t0=performance.now();window.addEventListener('flutter-first-frame',function(){window.__ff=performance.now()-window.__t0;});")
                pg.goto(f"http://127.0.0.1:8080/?{q}", wait_until="domcontentloaded", timeout=60000)
                for k, t in enumerate((0.35, 0.5, 0.5, 0.6, 0.8)):
                    time.sleep(t); pg.screenshot(path=f"{out}/{name}_{k}.png")
                pg.wait_for_load_state("networkidle")
                time.sleep(3)
                try:
                    ff = pg.evaluate("window.__ff")
                    gone = pg.evaluate("!document.getElementById('asp-splash')")
                    open(f"{out}/timing.txt", "w").write(f"first-frame-ms={ff}\nsplash-gone-after-load={gone}\n")
                except Exception as e:
                    open(f"{out}/timing.txt", "w").write(f"error {e}\n")
            else:
                pg.goto(f"http://127.0.0.1:8080/{q}" if q.startswith("asp-") else f"http://127.0.0.1:8080/?{q}", wait_until="networkidle", timeout=60000)
            if name.startswith("fx"):
                # ئەنیمەیشن: وێنە ل دەمێن جودا
                for k in range(8):
                    time.sleep(0.4); pg.screenshot(path=f"{out}/{name}_{k}.png")
            if name == "pathgold":
                for k in range(8):
                    time.sleep(0.45); pg.screenshot(path=f"{out}/{name}_early{k}.png")
            time.sleep(9)
            pg.screenshot(path=f"{out}/{name}.png")
            if name == "home_hdr":
                # بچە سەر وانەیا نوکە و بکە تپ ➔ پەڕێ وانێ
                for y in range(300, 800, 60):
                    pg.mouse.wheel(0, 0)
                pg.screenshot(path=f"{out}/{name}_1.png")
            if name.startswith("home_"):
                pg.mouse.click(214, 708); time.sleep(1.2)  # 🎁 دیالۆگا ئەرکان بگرە
                pg.screenshot(path=f"{out}/{name}.png")
            if name == "gate_ios":
                pg.mouse.click(214, 592); time.sleep(2.5); pg.screenshot(path=f"{out}/{name}_coach.png")
            if name.startswith("path") and not name.startswith("pathgold"):
                for k in range(3):
                    time.sleep(0.6); pg.screenshot(path=f"{out}/{name}_a{k}.png")
                pg.mouse.move(214, 500)
                pg.mouse.wheel(0, 900); time.sleep(1.0); pg.screenshot(path=f"{out}/{name}_down.png")
                pg.mouse.wheel(0, 2400); time.sleep(1.0); pg.screenshot(path=f"{out}/{name}_down2.png")
            if name.startswith("gloss"):
                for k in range(5):
                    time.sleep(1.0); pg.screenshot(path=f"{out}/{name}_{k}.png")
            if name == "toast":
                for k in range(16):
                    time.sleep(0.8); pg.screenshot(path=f"{out}/{name}_{k:02d}.png")
            if name == "streak":
                for k in range(4):
                    time.sleep(0.5); pg.screenshot(path=f"{out}/{name}_{k}.png")
            if name.startswith("combo"):
                time.sleep(0.3); pg.screenshot(path=f"{out}/{name}_b.png")
            if name == "chapter":
                pg.mouse.move(214, 500)
                for k in range(8):
                    pg.mouse.wheel(0, 3000); time.sleep(0.3)
                time.sleep(0.8); pg.screenshot(path=f"{out}/{name}_end.png")
            if name.startswith("bookpractice"):
                pg.mouse.click(214, 560); time.sleep(0.4); pg.mouse.click(214, 882); time.sleep(0.9)
                pg.screenshot(path=f"{out}/{name}_checked.png")
            if name == "examhint":
                for k in range(3):
                    pg.mouse.click(214, 290); time.sleep(0.7); pg.screenshot(path=f"{out}/{name}_h{k+1}.png")
                pg.mouse.wheel(0, 600); time.sleep(0.5); pg.screenshot(path=f"{out}/{name}_h3b.png")
                pg.mouse.wheel(0, -600); time.sleep(0.4)
                pg.mouse.click(214, 461); time.sleep(0.4); pg.mouse.click(214, 882); time.sleep(0.8)
                pg.screenshot(path=f"{out}/{name}_checked.png")
            if name == "examtype":
                pg.mouse.click(214, 313); time.sleep(0.6); pg.keyboard.type("tschüss"); time.sleep(0.5)
                pg.mouse.click(214, 880); time.sleep(0.9); pg.screenshot(path=f"{out}/{name}_checked.png")
            if name.startswith("pathgold"):
                pg.mouse.move(214, 500)
                pg.mouse.wheel(0, -1500); time.sleep(1.0); pg.screenshot(path=f"{out}/{name}_up.png")
                pg.mouse.wheel(0, -700); time.sleep(1.0); pg.screenshot(path=f"{out}/{name}_up2.png")
            if name.startswith("lesson"):
                # 👆 تبل ل سەر پەیڤەکێ ➔ بالۆنا رامانێ؛ پاشان چاڤ ➔ رامانا رستێ
                pg.mouse.click(92, 350); time.sleep(0.7); pg.screenshot(path=f"{out}/{name}_tap.png")
                pg.mouse.click(300, 350); time.sleep(0.7); pg.screenshot(path=f"{out}/{name}_tap2.png")
                pg.mouse.click(70, 397); time.sleep(0.7); pg.screenshot(path=f"{out}/{name}_eye.png")
            if name == "links":
                pg.mouse.click(96, 882); time.sleep(1.2); pg.screenshot(path=f"{out}/{name}_add.png")
            if name == "path":
                pg.mouse.move(214, 500)
                for k in range(14):
                    pg.mouse.wheel(0, 5000); time.sleep(0.35)
                time.sleep(0.8); pg.screenshot(path=f"{out}/{name}_end.png")
            if name == "pathdone":
                pg.mouse.move(214, 500)
                for k in range(6):
                    pg.mouse.wheel(0, -6000); time.sleep(0.35)
                time.sleep(0.8); pg.screenshot(path=f"{out}/{name}_top.png")
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
