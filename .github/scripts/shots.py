"""وێنەگرتنا ?demo=mascot ب Playwright — بۆ پشکنینا لڤین و جهێ کاریکاتێران."""
import os, time
from playwright.sync_api import sync_playwright

out = "/tmp/shots"
os.makedirs(out, exist_ok=True)
with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    pg = b.new_page(viewport={"width": 428, "height": 926}, device_scale_factor=2)
    pg.goto("http://127.0.0.1:8080/?demo=mascot", wait_until="networkidle")
    time.sleep(12)
    for i in range(14):
        pg.screenshot(path=f"{out}/s{i:02d}.png")
        time.sleep(0.45)
    b.close()
print("shots ok")
