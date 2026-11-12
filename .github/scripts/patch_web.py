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
s = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r"\1ASP", s)
extra = ('  <meta name="apple-mobile-web-app-capable" content="yes">\n'
         '  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">\n'
         '  <meta name="theme-color" content="#131F24">\n'
         '  <style>html,body{background:#0d0507;margin:0}</style>\n')
# 📐 viewport ژ دەستپێکێ (وەکی یێ Flutter) ➔ شاشا دەستپێکێ ناهێتە مەزنکرن/بچووککرن (نابەزیت)
if 'name="viewport"' not in s:
    s = s.replace("<head>", '<head>\n  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">', 1)
s = s.replace("<style>body{background:#131F24}</style>", "<style>html,body{background:#0d0507;margin:0}</style>")
# 🖤 iPhone: وێنەیێ دەستپێکێ (هەمان رەنگ) ل جهێ شاشا رەش
_sl = Path("branding/web/splash/startup_links.html")
if _sl.exists() and "apple-touch-startup-image" not in s:
    s = s.replace("</head>", _sl.read_text(encoding="utf-8") + "</head>", 1)
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
    if (B / "privacy.html").exists():
        shutil.copy(B / "privacy.html", "web/privacy.html")  # 🔒 بۆ Facebook/Google
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

# 🔐 زڤڕین ژ Google/Facebook: تۆکنان ژ #… بگرە و پاشەکەفت بکە (بەری Flutter دەستپێبکەت)
s = i.read_text(encoding="utf-8")
if "__aspOAuth" not in s:
    js = ("<script>(function(){try{var h=location.hash||'';"
          "if(h.indexOf('access_token=')>-1||h.indexOf('error_description=')>-1){"
          "localStorage.setItem('flutter.oauth_hash',JSON.stringify(h.substring(1)));"
          "history.replaceState(null,'',location.pathname+location.search);"
          "var sa=window.matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;"
          "if(!sa&&/iphone|ipad|ipod/i.test(navigator.userAgent)&&localStorage.getItem('flutter.oauth_pending')){window.__aspOAuthDone=true;}"
          "}}catch(e){}})();</script>\n")
    s = s.replace("<head>", "<head>\n  " + js, 1)
    i.write_text(s, encoding="utf-8")
    print("oauth hash capture added")

# ✨ شاشا دەستپێکێ (ASP-POYA): هەر جارا ئەپ ڤەدبیت، هەتا Flutter ئامادە دبیت (کێمتر نە ژ ~٣ چرکان)
SP = Path("branding/web/splash")
if SP.exists():
    Path("web/splash").mkdir(parents=True, exist_ok=True)
    for f in SP.iterdir():
        if f.name != "splash.html":
            shutil.copy(f, Path("web/splash") / f.name)
    s = i.read_text(encoding="utf-8")
    if "asp-splash" not in s:
        s = re.sub(r"(<body[^>]*>)", lambda m: m.group(1) + "\n" + (SP / "splash.html").read_text(encoding="utf-8"), s, count=1)
        i.write_text(s, encoding="utf-8")
        print("splash added")

# ⚡ زووتر ڤەبوون: فایلێن مەزن ژ دەستپێکێ پێکڤە دهێنە داگرتن
s = i.read_text(encoding="utf-8")
if "asp-preload" not in s:
    pre = ('  <!-- asp-preload -->\n'
           '  <link rel="preconnect" href="https://www.gstatic.com" crossorigin>\n'
           '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
           '  <link rel="preload" href="main.dart.js" as="script">\n')
    s = s.replace("</head>", pre + "</head>", 1)
    i.write_text(s, encoding="utf-8")
    print("preload hints added")
