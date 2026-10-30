"""ناڤ، رەنگ و شێوازێ ئەپێ iPhone بۆ web/ پشتی `flutter create`."""
import json
import re
from pathlib import Path

m = Path("web/manifest.json")
d = json.loads(m.read_text(encoding="utf-8"))
d.update(name="ASP", short_name="ASP", background_color="#131F24", theme_color="#131F24",
         description="فێربوونا ئەلمانی ب کوردی بادینی — Deutsch · English · Badini", orientation="portrait")
m.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")

i = Path("web/index.html")
s = i.read_text(encoding="utf-8")
s = re.sub(r"<title>.*?</title>", "<title>ASP</title>", s, flags=re.S)
s = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r"\1ZimanPro", s)
extra = ('  <meta name="apple-mobile-web-app-capable" content="yes">\n'
         '  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">\n'
         '  <meta name="theme-color" content="#131F24">\n'
         '  <style>body{background:#131F24}</style>\n')
if "black-translucent" not in s:
    s = s.replace("</head>", extra + "</head>", 1)
i.write_text(s, encoding="utf-8")
print("web patched")

# ───────── ASP branding ─────────
import shutil
B = Path("branding/web")
if B.exists():
    Path("web/icons").mkdir(parents=True, exist_ok=True)
    for n in ("Icon-192.png", "Icon-512.png", "Icon-maskable-192.png", "Icon-maskable-512.png"):
        shutil.copy(B / n, Path("web/icons") / n)
    shutil.copy(B / "favicon.png", "web/favicon.png")
    shutil.copy(B / "apple-touch-icon.png", "web/apple-touch-icon.png")
    if (B / "push-sw.js").exists():
        Path("web/push").mkdir(parents=True, exist_ok=True)
        shutil.copy(B / "push-sw.js", "web/push-sw.js")
    s = i.read_text(encoding="utf-8")
    if "apple-touch-icon.png" not in s:
        s = re.sub(r'<link rel="apple-touch-icon"[^>]*>', "", s)
        s = s.replace("</head>", '  <link rel="apple-touch-icon" href="apple-touch-icon.png">\n</head>', 1)
    s = re.sub(r"<title>.*?</title>", "<title>ASP</title>", s, flags=re.S)
    s = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r"\1ASP", s)
    i.write_text(s, encoding="utf-8")
    d = json.loads(m.read_text(encoding="utf-8"))
    d.update(name="ASP", short_name="ASP")
    m.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    print("ASP branding applied")

# Android/Chrome: پاشەکەفتکرنا رووداوێ دامەزراندنێ دا ئەپ بشێت دوگمەیا «دامەزراندن» نیشان بدەت
s = i.read_text(encoding="utf-8")
if "__aspInstall" not in s:
    s = s.replace("</head>", "  <script>window.addEventListener('beforeinstallprompt',function(e){e.preventDefault();window.__aspInstall=e;});</script>\n</head>", 1)
    i.write_text(s, encoding="utf-8")
    print("install prompt hook added")

# وەسفا ئەپی (بۆ لینکێن هاتینە پارڤەکرن)
s = i.read_text(encoding="utf-8")
s = re.sub(r'<meta name="description" content="[^"]*">',
           '<meta name="description" content="ASP — فێربوونا ئەلمانی ب کوردی بادینی · Deutsch lernen auf Kurdisch">', s)
i.write_text(s, encoding="utf-8")
