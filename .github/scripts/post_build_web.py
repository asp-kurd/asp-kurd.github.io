"""پشتی flutter build web: build_id.txt + ?v=<id> بۆ main.dart.js و flutter_bootstrap.js (دا کاش کەڤن نەمینیت)."""
import re, sys
from pathlib import Path

bid = sys.argv[1]
web = Path("build/web")
(web / "build_id.txt").write_text(bid, encoding="utf-8")

boot = web / "flutter_bootstrap.js"
if boot.exists():
    s = boot.read_text(encoding="utf-8")
    n = s.count('"mainJsPath":"main.dart.js"')
    s = s.replace('"mainJsPath":"main.dart.js"', f'"mainJsPath":"main.dart.js?v={bid}"')
    boot.write_text(s, encoding="utf-8")
    print("bootstrap mainJsPath patched:", n)

idx = web / "index.html"
s = idx.read_text(encoding="utf-8")
s = re.sub(r'src="flutter_bootstrap\.js(\?v=[^"]*)?"', f'src="flutter_bootstrap.js?v={bid}"', s)
s = re.sub(r'src="main\.dart\.js(\?v=[^"]*)?"', f'src="main.dart.js?v={bid}"', s)
s = re.sub(r'href="main\.dart\.js(\?v=[^"]*)?"', f'href="main.dart.js?v={bid}"', s)  # ⚡ preload
idx.write_text(s, encoding="utf-8")
print("build id:", bid)

# 🛡️ پەڕێ ئەدمینی یێ جودا: /asp-d7k2/ — manifest و ناڤێ خۆ هەنە دا ل Home Screen وەکی «ASP Admin» بمینیت
import json
adm = web / "asp-d7k2"
adm.mkdir(exist_ok=True)
a = s
a = re.sub(r"<title>.*?</title>", "<title>ASP Admin</title>", a, flags=re.S)
a = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r"\1ASP Admin", a)
a = re.sub(r'<link rel="manifest"[^>]*>', '<link rel="manifest" href="/asp-d7k2/manifest.json">', a)
a = a.replace("</head>", "  <script>window.__aspAdmin=true;</script>\n</head>", 1)
(adm / "index.html").write_text(a, encoding="utf-8")
man = json.loads((web / "manifest.json").read_text(encoding="utf-8"))
man.update(name="ASP Admin", short_name="ASP Admin", start_url="/asp-d7k2/", scope="/asp-d7k2/", id="/asp-d7k2/")
for ic in man.get("icons", []):
    ic["src"] = "/" + ic["src"].lstrip("/")
(adm / "manifest.json").write_text(json.dumps(man, ensure_ascii=False, indent=2), encoding="utf-8")
print("admin page: /asp-d7k2/")
