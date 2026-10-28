# ZimanPro 3.0 — فێربوونا زمانان ب دەنگێ تە یێ کلۆنکری 🧬

ئەپێ Flutter بۆ فێربوونا ئەلمانی و ئینگلیزی ب کوردی بادینی (و بەروڤاژی).
تو ١٠ تا ٢٠ چرکەیان ژ دەنگێ خۆ تۆمار دکەی، و AI هەمی وانەیان ب **دەنگێ تە** ب سێ زمانان دبێژیت.

## 📱 تنێ مۆبایل؟ (بێ کۆمپیوتەر)
1. **APK:** پرۆژەی بخە سەر GitHub. `.github/workflows/build_apk.yml` ب بێ پارە APK دروست دکەت.
   ل GitHub بچە: Actions ➔ Build APK ➔ دویماهیک run ➔ Artifacts ➔ `ZimanPro-apk`. داگرە و دامەزرینە.
2. **دەنگ:** `ZimanPro_Voice_Lab.ipynb` ل Colab ڤەکە (ب Chrome) ➔ `voice_pack.zip` داگرە.
3. **هاوردەکرن:** ل ئەپی: `دەنگێ من ➔ 🧬 ➔ هاوردەکرنا voice_pack.zip`. ئیدی پێدڤی ب build نینە.

## چ یێ نوو ل 3.0
| | |
|---|---|
| 🧬 **کلۆنکرنا دەنگی** | نموونەیەکا کورت ➔ هەمی ٦٢ پەیڤ × ٣ زمان ب دەنگێ تە |
| 📚 **١٠ قۆناغ / ٦٢ پەیڤ** | رەنگ، لەش، کریار و رستەیێن ژیانێ هاتنە زێدەکرن |
| 🔗 **جووتکرن** | ل دەستپێکا هەر وانەیەکێ، ٤ جووت |
| 🧩 **ئاڤاکرنا رستێ** | رستێ ژ پارچەیان ئاڤا دکەی (وەکی Duolingo) |
| ☀️ **ئارمانجا رۆژانە** | ٢٠ / ٣٠ / ٥٠ / ٨٠ XP. رۆژ ب XPیێن تە رۆهن دبیت |
| 🏅 **١٠ دەستکەفت** | Streak، وانەیا بێ خەلەتی، دەنگێ کلۆنکری ... |
| 📄 **curriculum.json** | ئێک فایل بۆ ئەپی و بۆ دروستکرنا دەنگان ژی |

## سیستەمێ دەنگی — رێزا گرنگیێ
بۆ هەر پەیڤەکێ ئەپ ڤی رێزی دشۆپینیت:
1. 🎤 **تۆمارێ تە ب دەست** (ستۆدیۆ). ئەڤە هەردەم ل پێشیێیە
2. 🧬 **دەنگێ کلۆنکری ژ سێرڤەری** (`documents/cloned/`)
3. 📦 **پاکێتا دەنگی ژ Colab** (`assets/voices/`)
4. 🤖 **TTS** (تنێ بۆ ئەلمانی و ئینگلیزی)

## 🧬 چاوا دەنگێ خۆ کلۆن بکەی

**مۆدێل:** [`Dezheen89/omnivoice-badini`](https://huggingface.co/Dezheen89/omnivoice-badini) بۆ بادینی، کو ب تایبەتی ل سەر ئاخفتنا بادینی هاتیە ڕاهێنان.
[`k2-fsa/OmniVoice`](https://huggingface.co/k2-fsa/OmniVoice) بۆ ئەلمانی و ئینگلیزی، کو ٦٠٠+ زمانان پشتگیری دکەت.
پێدڤی ب GPU یە. **Google Colab یا بێ پارە (T4)** بەسە.

### پێنگاڤا ١ — نموونەیێ تۆمار بکە (د ئەپی دا)
`دەنگێ من ➔ 🧬 کلۆنکرنا دەنگێ من`. دەقێ بادینی بخوینە (پێدڤییە). دەقێن ئەلمانی و ئینگلیزی ئارەزوومەندانەنە، بەلێ ئەکسێنتێ باشتر دکەن.

### پێنگاڤا ٢ — یەکێ ژ دوو رێکان هەلبژێرە
**🅰️ Colab ➔ پاکێتا دەنگی (ب ساناهی):**
1. نموونەیێ ب دوگمەیا 📤 بۆ خۆ فرێکە.
2. `voice_lab/ZimanPro_Voice_Lab.ipynb` ل [colab.research.google.com](https://colab.research.google.com) ڤەکە و `T4 GPU` هەلبژێرە.
3. خانەیان ئێک ل دویف ئێکێ Run بکە، و نموونەیێ بار بکە.
4. پشتی گوهلێبوونا تاقیکرنێ، `voice_pack.zip` داگرە.
5. ناڤەرۆکا وێ ڤەکە د `assets/voices/` دا، و پاشان `flutter run` بکە.

**🅱️ سێرڤەرێ زیندی (راستەوخۆ ژ ئەپی):**
1. د Colab دا، خانەیا ٦ Run بکە. ئەو `Server URL` و `Token` ددەتە تە.
2. ل ئەپی، ئەوان بنڤیسە و `تاقیکرن` بکە. پاشان `هەمی وانە ب دەنگێ من دروست بکە` بکە.

یان ل سەر کۆمپیوتەرەکێ خۆ یێ ب GPU:
```bash
cd voice_lab
pip install omnivoice soundfile fastapi uvicorn python-multipart
ZIMAN_TOKEN=secret uvicorn server:app --host 0.0.0.0 --port 8000
# یان بۆ پاکێتێ:
python generate_pack.py --ref-ku my_voice.m4a --ref-de de.m4a --ref-en en.m4a
```

> ⚠️ **تنێ دەنگێ خۆ.** ئەپ و سێرڤەر پشتڕاستکرنا دەستووریێ (consent) دخوازن.
> مۆدێلێ OmniVoice ب لیسانسا **CC-BY-NC** یە، ئانکو بۆ بکارئینانا نە-بازرگانی. ئەگەر تە ڤیا ئەپی بفرۆشی، دڤێت خزمەتگوزاریەکا بازرگانی (وەکی ElevenLabs) ب کار بینی.

## دامەزراندن
```bash
cd zimanpro
flutter create . --platforms=android,ios
flutter pub get
flutter run
```

### ⚠️ دەستووریێن پێدڤی
**Android** — `android/app/src/main/AndroidManifest.xml`، بەری `<application`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```
`minSdk = 23` ل `android/app/build.gradle(.kts)`

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>ZimanPro دڤێت دەنگێ تە تۆمار بکەت بۆ فێربوونێ</string>
```

## پێکهاتا پرۆژەی
```
assets/curriculum.json          ← هەمی وانە (پەیڤێن نوو ل ڤێرێ زێدە بکە)
assets/voices/                  ← پاکێتا دەنگێ کلۆنکری ژ Colab
lib/
  main.dart · models.dart · ui.dart
  data/curriculum.dart          ← خواندنا JSON
  services/voice_service.dart   ← تۆمار، لێدان، رێزا ژێدەرێن دەنگی
  services/clone_service.dart   ← پەیوەندی دگەل سێرڤەرێ کلۆنکرنێ
  services/progress_service.dart← XP، Streak، دل، ئارمانج، دەستکەفت
  screens/  onboarding · home · lesson · voice_studio · voice_clone · profile
  screens/widgets/record_button.dart
voice_lab/
  ZimanPro_Voice_Lab.ipynb      ← Colab (بێ پارە)
  voice_core.py · generate_pack.py · server.py · curriculum.json
```

## زێدەکرنا پەیڤان
ل `assets/curriculum.json` زێدە بکە. پاشان ئەوی فایلی کۆپی بکە بۆ `voice_lab/` و پاکێتێ ژ نوو دروست بکە. بەس پەیڤێن نوو دێ هێنە دروستکرن، چونکی یێن بەری نوکە دهێنە دەرباز کرن.
