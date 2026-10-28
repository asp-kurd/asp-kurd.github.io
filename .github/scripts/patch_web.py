"""ناڤ، رەنگ و شێوازێ ئەپێ iPhone بۆ web/ پشتی `flutter create`."""
import json
import re
from pathlib import Path

m = Path("web/manifest.json")
d = json.loads(m.read_text(encoding="utf-8"))
d.update(name="ZimanPro", short_name="ZimanPro", background_color="#131F24", theme_color="#131F24",
         description="فێربوونا زمانان ب دەنگێ تە — Badini · Deutsch · English", orientation="portrait")
m.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")

i = Path("web/index.html")
s = i.read_text(encoding="utf-8")
s = re.sub(r"<title>.*?</title>", "<title>ZimanPro</title>", s, flags=re.S)
s = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r"\1ZimanPro", s)
extra = ('  <meta name="apple-mobile-web-app-capable" content="yes">\n'
         '  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">\n'
         '  <meta name="theme-color" content="#131F24">\n'
         '  <style>body{background:#131F24}</style>\n')
if "black-translucent" not in s:
    s = s.replace("</head>", extra + "</head>", 1)
i.write_text(s, encoding="utf-8")
print("web patched")
