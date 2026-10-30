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
m = re.sub(r'android:label="[^"]*"', 'android:label="ASP"', m, count=1)
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

# پلاگینێن کەڤن (وەکی file_picker) ل سەر android-34 دهێنە ئاڤاکرن، بەلێ
# پشکێن نوو compileSdk 36 دخوازن. ئەم compileSdk ـا هەمی پلاگینان دکەینە 36.
FORCE_SDK_KTS = '''
// ZimanPro: force compileSdk 36 for plugins built against older Android SDKs
subprojects {
    if (name != "app") {
        val zimanForceSdk: Project.() -> Unit = {
            extensions.findByName("android")?.let { ext ->
                try {
                    ext.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, 36)
                } catch (e: Exception) {
                    try {
                        ext.javaClass.getMethod("setCompileSdk", Int::class.javaObjectType).invoke(ext, 36)
                    } catch (e2: Exception) {
                        logger.warn("ZimanPro: could not set compileSdk for $name")
                    }
                }
            }
        }
        if (state.executed) zimanForceSdk() else afterEvaluate { zimanForceSdk() }
    }
}
'''
FORCE_SDK_GROOVY = '''
// ZimanPro: force compileSdk 36 for plugins built against older Android SDKs
subprojects {
    if (name != "app") {
        def zimanForceSdk = { p -> if (p.hasProperty("android")) { p.android.compileSdkVersion 36 } }
        if (state.executed) zimanForceSdk(delegate) else afterEvaluate { zimanForceSdk(it) }
    }
}
'''
for name, block in (("android/build.gradle.kts", FORCE_SDK_KTS), ("android/build.gradle", FORCE_SDK_GROOVY)):
    g = Path(name)
    if not g.exists():
        continue
    s = g.read_text(encoding="utf-8")
    if "ZimanPro: force compileSdk" in s:
        continue
    # دڤێت بەری evaluationDependsOn بهێتە زێدەکرن
    i = s.find("subprojects {")
    s = (s[:i] + block.lstrip("\n") + "\n" + s[i:]) if i >= 0 else (s + block)
    g.write_text(s, encoding="utf-8")
    print(f"{name}: plugins compileSdk 36")

# ───────── ASP branding ─────────
import shutil
B = Path("branding/android")
if B.exists():
    for d in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
        dst = Path(f"android/app/src/main/res/mipmap-{d}")
        if dst.exists():
            shutil.copy(B / f"{d}.png", dst / "ic_launcher.png")
    m = manifest.read_text(encoding="utf-8")
    m = re.sub(r'android:label="[^"]*"', 'android:label="ASP"', m, count=1)
    manifest.write_text(m, encoding="utf-8")
    print("ASP icons applied")
