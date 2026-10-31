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
idx.write_text(s, encoding="utf-8")
print("build id:", bid)
