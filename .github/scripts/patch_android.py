"""زێدەکرنا دەستووریێن پێدڤی بۆ android/ پشتی `flutter create`."""
import re
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text(encoding="utf-8")
perms = [
    "android.permission.RECORD_AUDIO",
    "android.permission.INTERNET",
]
add = "".join(f'    <uses-permission android:name="{p}" />\n' for p in perms if p not in m)
if add:
    m = m.replace("<application", add + "    <application", 1)
# ناڤێ ئەپی ل سەر مۆبایلێ
m = re.sub(r'android:label="[^"]*"', 'android:label="ZimanPro"', m, count=1)
manifest.write_text(m, encoding="utf-8")
print("Manifest patched")

for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    g = Path(name)
    if not g.exists():
        continue
    s = g.read_text(encoding="utf-8")
    s = s.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
    s = s.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 24")
    g.write_text(s, encoding="utf-8")
    print(f"{name}: minSdk 24")
