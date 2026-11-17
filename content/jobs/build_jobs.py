"""💼 پەیڤێن کاری (A1) ➔ assets/jobs.json
هەر کارەک: ١٠ پەیڤ + ٥ رستە. ریز: de | ku | deHint (خواندن ب کوردی) | en | emoji
"""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]

JOBS = [
 ("supermarkt", "🛒", "سوپەرمارکێت", "Supermarkt", "Supermarket", """
die Kasse | سندووقا پارەی | دی کاسە | the checkout | 💶
der Kunde | کڕیار | دێر کوندە | the customer | 🧑
das Regal | ڕەفک | داس ڕێگال | the shelf | 🗄️
der Einkaufswagen | عەرەبانەیا کڕینێ | دێر ئاینکاوفسڤاگن | the shopping cart | 🛒
die Tüte | کیس | دی تووتە | the bag | 🛍️
das Preisschild | نیشانا بهای | داس پرایسشیلت | the price tag | 🏷️
das Lager | کۆگە | داس لاگەر | the storeroom | 📦
die Quittung | پسوولە | دی کڤیتونگ | the receipt | 🧾
das Angebot | داشکاندن | داس ئانگەبۆت | the special offer | 🔖
die Waage | تەرازی | دی ڤاگە | the scale | ⚖️
""", """
Kann ich Ihnen helfen? | ئەرێ دشێم هاریکاریا هەوە بکەم؟ | Can I help you?
Das kostet fünf Euro. | ئەڤە ب پێنج یۆرۆیانە. | That costs five euros.
Möchten Sie eine Tüte? | ئەرێ هوین کیسەکێ دخوازن؟ | Would you like a bag?
Bar oder mit Karte? | ب نەقدی یان ب کارتێ؟ | Cash or card?
Die Milch ist dort im Regal. | شیر ل وێرێ ل سەر ڕەفکێ یە. | The milk is on the shelf over there.
"""),
 ("hausmeister", "🔧", "چاکسازی و هەستا", "Hausmeister", "Maintenance", """
der Hammer | چەکووچ | دێر هامەر | the hammer | 🔨
der Schraubenzieher | دەرنەڤیس | دێر شراوبنتسیەر | the screwdriver | 🪛
die Leiter | پەیژە | دی لایتەر | the ladder | 🪜
die Lampe | گلۆپ | دی لامپە | the lamp | 💡
das Werkzeug | ئامیر | داس ڤێرکتسۆیگ | the tools | 🧰
die Heizung | ئامیرێ گەرمکرنێ | دی هایتسونگ | the heating | ♨️
der Wasserhahn | شێرێ ئاڤێ | دێر ڤاسەرهان | the tap | 🚰
der Schlüssel | کلیل | دێر شلووسل | the key | 🔑
die Tür | دەرگەهـ | دی توور | the door | 🚪
kaputt | خەراب | کاپوت | broken | 🛠️
""", """
Die Heizung ist kaputt. | ئامیرێ گەرمکرنێ خەراب بوویە. | The heating is broken.
Ich repariere das sofort. | ئەز ئێکسەر ڤێ چاک دکەم. | I'll repair it right away.
Wo ist das Problem? | ئاریشە ل کیڤەیە؟ | Where is the problem?
Ich brauche eine Leiter. | پێدڤیا من ب پەیژەکێ هەیە. | I need a ladder.
Ich komme morgen um neun Uhr. | ئەز سوبەهی دەمژمێر نەهـ دێ هێم. | I'll come tomorrow at nine.
"""),
 ("krankenhaus", "🏥", "نەخۆشخانە و پەرستار", "Krankenhaus", "Hospital", """
die Krankenschwester | پەرستار | دی کرانکنشڤێستەر | the nurse | 👩‍⚕️
der Patient | نەخۆش | دێر پاتسیێنت | the patient | 🛌
das Bett | تەخت | داس بێت | the bed | 🛏️
die Spritze | دەرزی | دی شپریتسە | the injection | 💉
das Fieber | تا | داس فیبەر | the fever | 🤒
die Tablette | حەب | دی تابلێتە | the pill | 💊
der Schmerz | ئێش | دێر شمێرتس | the pain | 🤕
das Thermometer | پیڤەرا گەرمیێ | داس تێرمۆمێتەر | the thermometer | 🌡️
der Notfall | فریاکەفتن | دێر نۆتفال | the emergency | 🚑
das Blut | خوین | داس بلووت | the blood | 🩸
""", """
Wie geht es Ihnen heute? | ئەڤرۆ هوین چاوانن؟ | How are you today?
Haben Sie Schmerzen? | ئەرێ ئێش هەیە؟ | Are you in pain?
Bitte nehmen Sie diese Tablette. | هیڤیە ڤێ حەبێ بخۆن. | Please take this pill.
Ich messe jetzt Fieber. | نوکە ئەز تایا هەوە دپیڤم. | I'm taking your temperature now.
Ich komme gleich. | ئەز نوکە دهێم. | I'm coming right away.
"""),
 ("arztpraxis", "🩺", "دکتۆر و نۆڕینگەهـ", "Arztpraxis", "Doctor's office", """
der Arzt | دکتۆر | دێر ئارتست | the doctor | 🧑‍⚕️
der Termin | ژڤان | دێر تێرمین | the appointment | 📅
das Wartezimmer | ژوورا چاڤەڕێکرنێ | داس ڤارتەتسیمەر | the waiting room | 🪑
die Versichertenkarte | کارتا بیمەیێ | دی فێرزیشەرتنکارتە | the insurance card | 💳
das Rezept | ڕەچەتە | داس ڕێتسێپت | the prescription | 📝
die Apotheke | دەرمانخانە | دی ئاپۆتێکە | the pharmacy | ⚕️
der Kopf | سەر | دێر کۆپف | the head | 🙆
der Bauch | زک | دێر باوخ | the stomach | 🤢
krank | نەخۆش | کرانک | sick | 🤧
die Krankmeldung | ڕاپۆرتا نەخۆشیێ | دی کرانکمێلدونگ | the sick note | 📄
""", """
Ich möchte einen Termin. | ئەز ژڤانەکێ دخوازم. | I'd like an appointment.
Haben Sie Ihre Versichertenkarte? | ئەرێ کارتا بیمەیا هەوە دگەل هەوە یە؟ | Do you have your insurance card?
Bitte warten Sie im Wartezimmer. | هیڤیە ل ژوورا چاڤەڕێکرنێ چاڤەڕێ بکەن. | Please wait in the waiting room.
Mein Kopf tut weh. | سەرێ من دئێشیت. | My head hurts.
Seit wann sind Sie krank? | ژ کەنگی ڤە هوین نەخۆشن؟ | Since when have you been sick?
"""),
 ("kita", "🧸", "باخچێ زارۆکان", "Kita", "Kindergarten", """
das Kind | زارۆک | داس کیند | the child | 🧒
die Erzieherin | پەروەردەکار | دی ئێرتسیەرین | the educator | 👩‍🏫
das Spielzeug | یاریک | داس شپیلتسۆیگ | the toy | 🧸
der Ball | تۆپ | دێر بال | the ball | ⚽
die Windel | پەمپەرز | دی ڤیندل | the diaper | 👶
das Buch | پەرتووک | داس بووخ | the book | 📖
malen | وێنە کێشان | مالن | to paint | 🎨
schlafen | نڤستن | شلافن | to sleep | 😴
der Spielplatz | جهێ یاریان | دێر شپیلپلاتس | the playground | 🛝
die Eltern | دایک و باب | دی ئێلتەرن | the parents | 👨‍👩‍👧
""", """
Guten Morgen! Wie heißt du? | سپێدە باش! ناڤێ تە چیە؟ | Good morning! What's your name?
Wasch dir bitte die Hände. | هیڤیە دەستێن خۆ بشۆ. | Please wash your hands.
Jetzt essen wir zusammen. | نوکە ئەم پێکڤە دخۆین. | Now we eat together.
Deine Mama kommt um drei Uhr. | دایکا تە دەمژمێر سێ دهێت. | Your mum comes at three.
Wir gehen auf den Spielplatz. | ئەم دچینە جهێ یاریان. | We're going to the playground.
"""),
 ("altenpflege", "👵", "خانیێ پیران", "Altenpflege", "Elderly care", """
die Bewohnerin | ئاکنجی | دی بەڤۆنەرین | the resident | 👵
der Rollstuhl | کورسیکا ب تەکەر | دێر ڕۆلشتوول | the wheelchair | 🦽
das Medikament | دەرمان | داس مێدیکامێنت | the medicine | 💊
waschen | شویشتن | ڤاشن | to wash | 🧼
das Handtuch | خاولی | داس هانتووخ | the towel | 🧺
der Stock | گۆچان | دێر شتۆک | the walking stick | 🦯
das Essen | خوارن | داس ئێسن | the food | 🍲
trinken | ڤەخوارن | ترینکن | to drink | 🥤
spazieren gehen | گەڕیان | شپاتسیرن گێەن | to go for a walk | 🚶
die Brille | بەرچاڤک | دی بریلە | the glasses | 👓
""", """
Guten Morgen! Haben Sie gut geschlafen? | سپێدە باش! ئەرێ هوین باش نڤستن؟ | Good morning! Did you sleep well?
Möchten Sie etwas trinken? | ئەرێ هوین دخوازن تشتەکی ڤەخۆن؟ | Would you like something to drink?
Ich helfe Ihnen beim Aufstehen. | ئەز هاریکاریا هەوە دکەم دا ڕابن. | I'll help you get up.
Hier ist Ihre Brille. | ئەڤە بەرچاڤکا هەوە یە. | Here are your glasses.
Wir gehen jetzt spazieren. | نوکە ئەم دچینە گەڕیانێ. | We're going for a walk now.
"""),
 ("restaurant", "🍽️", "خوارنگەهـ", "Restaurant", "Restaurant", """
die Speisekarte | لیستا خوارنێ | دی شپایزەکارتە | the menu | 📋
der Kellner | گارسۆن | دێر کێلنەر | the waiter | 🤵
die Küche | مەتبەخ | دی کووشە | the kitchen | 🍳
der Teller | قاپ | دێر تێلەر | the plate | 🍽️
das Glas | پەرداخ | داس گلاس | the glass | 🥛
die Rechnung | حسێب | دی ڕێشنونگ | the bill | 🧾
der Tisch | مێز | دێر تیش | the table | 🪑
bestellen | داخوازکرن | بەشتێلن | to order | ✍️
der Koch | ئاشپێژ | دێر کۆخ | the cook | 👨‍🍳
das Trinkgeld | بەخشیش | داس ترینکگێلت | the tip | 💶
""", """
Was möchten Sie trinken? | هوین دخوازن چ ڤەخۆن؟ | What would you like to drink?
Einen Tisch für zwei, bitte. | مێزەک بۆ دوو کەسان، هیڤیە. | A table for two, please.
Hat es Ihnen geschmeckt? | ئەرێ خوارن ب دلێ هەوە بوو؟ | Did you enjoy the food?
Die Rechnung, bitte. | حسێب، هیڤیە. | The bill, please.
Das Essen kommt gleich. | خوارن نوکە دهێت. | The food is coming soon.
"""),
 ("lager", "📦", "کۆگە و پاکێت", "Lager", "Warehouse", """
das Paket | پاکێت | داس پاکێت | the package | 📦
der Karton | کارتۆن | دێر کارتۆن | the box | 🗃️
der Gabelstapler | فۆرکلیفت | دێر گابلشتاپلەر | the forklift | 🚜
schwer | گران | شڤێر | heavy | 🏋️
leicht | سڤک | لایشت | light | 🪶
der Scanner | سکانەر | دێر سکێنەر | the scanner | 📟
die Lieferung | گەهاندن | دی لیفەرونگ | the delivery | 🚚
die Schicht | دەوام | دی شیشت | the shift | ⏰
der Helm | کلاڤێ پاراستنێ | دێر هێلم | the helmet | ⛑️
die Handschuhe | دەستکێش | دی هانتشووە | the gloves | 🧤
""", """
Das Paket ist sehr schwer. | ئەڤ پاکێتە گەلەک گرانە. | This package is very heavy.
Wo soll ich das hinstellen? | ئەز ڤێ ل کیڤە دانم؟ | Where should I put this?
Meine Schicht beginnt um sechs Uhr. | دەوامێ من دەمژمێر شەش دەست پێ دکەت. | My shift starts at six.
Bitte tragen Sie Handschuhe. | هیڤیە دەستکێشان بکەنە دەستێن خۆ. | Please wear gloves.
Die Lieferung kommt heute. | گەهاندن ئەڤرۆ دهێت. | The delivery comes today.
"""),
 ("reinigung", "🧹", "پاقژکرن", "Reinigung", "Cleaning", """
der Besen | گسک | دێر بێزن | the broom | 🧹
der Eimer | سەتل | دێر ئایمەر | the bucket | 🪣
der Staubsauger | ماکینا پاقژکرنێ | دێر شتاوبزاوگەر | the vacuum cleaner | 🌀
putzen | پاقژکرن | پوتسن | to clean | 🧽
der Müll | زبل | دێر موول | the trash | 🗑️
das Fenster | پەنجەرە | داس فێنستەر | the window | 🪟
der Boden | ئەرد | دێر بۆدن | the floor | 🟫
die Toilette | تەوالێت | دی تۆئالێتە | the toilet | 🚽
sauber | پاقژ | زاوبەر | clean | ✨
schmutzig | پیس | شموتسیش | dirty | 🦠
""", """
Ich putze zuerst die Küche. | پێشی ئەز مەتبەخێ پاقژ دکەم. | First I clean the kitchen.
Der Boden ist noch nass. | ئەرد هێشتا تەڕە. | The floor is still wet.
Wo ist der Müll? | زبل ل کیڤەیە؟ | Where is the trash?
Das Fenster ist jetzt sauber. | پەنجەرە نوکە پاقژە. | The window is clean now.
Brauchen Sie noch etwas? | ئەرێ تشتەکێ دی پێدڤی یە؟ | Do you need anything else?
"""),
 ("friseur", "💈", "سەرتاش", "Friseur", "Hairdresser", """
die Haare | پرچ | دی هارە | the hair | 💇
die Schere | مقەس | دی شێرە | the scissors | ✂️
der Kamm | شە | دێر کام | the comb | 🪮
der Bart | ڕیهـ | دێر بارت | the beard | 🧔
kurz | کورت | کورتس | short | 📏
lang | درێژ | لانگ | long | 〰️
der Föhn | سێشوار | دێر فۆن | the hair dryer | 💨
der Spiegel | نەینک | دێر شپیگل | the mirror | 🪞
der Rasierer | ماکینا ڕیهێ | دێر ڕازیرەر | the razor | 🪒
schneiden | بڕین | شنایدن | to cut | 💇‍♂️
""", """
Wie möchten Sie die Haare? | هوین پرچا خۆ چاوا دخوازن؟ | How would you like your hair?
Nur ein bisschen kürzer, bitte. | تنێ هندەکێ کورتتر، هیڤیە. | Just a little shorter, please.
Den Bart auch? | ڕیهـ ژی؟ | The beard too?
Das macht fünfzehn Euro. | ئەڤە دبیتە پازدە یۆرۆ. | That's fifteen euros.
Gefällt es Ihnen? | ئەرێ ب دلێ هەوە یە؟ | Do you like it?
"""),
 ("fahrer", "🚚", "شۆفێر و گەهاندن", "Fahrer", "Driver", """
das Auto | ترومبێل | داس ئاوتۆ | the car | 🚗
der Lkw | لۆری | دێر ئێلکاڤێ | the truck | 🚛
die Straße | جادە | دی شتراسە | the street | 🛣️
die Adresse | ناڤنیشان | دی ئادرێسە | the address | 📍
links | چەپ | لینکس | left | ⬅️
rechts | ڕاست | ڕێشتس | right | ➡️
geradeaus | ڕاستەوخۆ | گەرادەئاوس | straight ahead | ⬆️
der Führerschein | ئیجازا شۆفێریێ | دێر فوورەرشاین | the driving licence | 🪪
tanken | بەنزین تێکرن | تانکن | to refuel | ⛽
die Ampel | گلۆپێن هاتووچوونێ | دی ئامپل | the traffic light | 🚦
""", """
Wo ist die Hausnummer zwölf? | خانیێ ژمارە دوازدە ل کیڤەیە؟ | Where is house number twelve?
Ich habe ein Paket für Sie. | پاکێتەک بۆ هەوە ل نک من هەیە. | I have a package for you.
Bitte hier unterschreiben. | هیڤیە ل ڤێرێ ئیمزا بکەن. | Please sign here.
An der Ampel links. | ل گلۆپێن هاتووچوونێ بچە لایێ چەپێ. | Turn left at the traffic light.
Ich komme in zehn Minuten. | ئەز پشتی دەهـ خولەکان دگەهم. | I'll be there in ten minutes.
"""),
 ("bau", "🏗️", "ئاڤاکرن", "Baustelle", "Construction", """
die Baustelle | جهێ ئاڤاکرنێ | دی باوشتێلە | the construction site | 🏗️
der Ziegel | بلۆک | دێر تسیگل | the brick | 🧱
der Zement | چیمەنتۆ | دێر تسێمێنت | the cement | 🪨
die Schaufel | مەڕ | دی شاوفل | the shovel | ⛏️
der Kran | کرێن | دێر کران | the crane | 🪝
der Bohrer | دریل | دێر بۆرەر | the drill | 🔩
das Holz | دار | داس هۆلتس | the wood | 🪵
die Wand | دیوار | دی ڤاند | the wall | 🏠
der Helm | کلاڤێ پاراستنێ | دێر هێلم | the helmet | ⛑️
tragen | هەلگرتن | تراگن | to carry | 💪
""", """
Vorsicht! Das ist gefährlich. | ئاگەهدار بە! ئەڤە مەترسیدارە. | Careful! That's dangerous.
Wir brauchen mehr Zement. | پێدڤیا مە ب چیمەنتۆیێ پتر هەیە. | We need more cement.
Bitte trag den Helm. | هیڤیە کلاڤێ پاراستنێ بکە سەرێ خۆ. | Please wear the helmet.
Die Pause ist um zwölf Uhr. | پشوو دەمژمێر دوازدە یە. | The break is at twelve.
Kannst du mir helfen? | دشێی هاریکاریا من بکەی؟ | Can you help me?
"""),
 ("baeckerei", "🥨", "نانەواخانە", "Bäckerei", "Bakery", """
das Brot | نان | داس برۆت | the bread | 🍞
das Brötchen | سەموون | داس برۆتشن | the bread roll | 🥖
der Kuchen | کێک | دێر کووخن | the cake | 🍰
das Mehl | ئارد | داس مێل | the flour | 🌾
der Ofen | فڕن | دێر ئۆفن | the oven | 🫓
backen | پێژان | باکن | to bake | 🧑‍🍳
frisch | تازە | فریش | fresh | 🌿
das Croissant | کرواسان | داس کرواسان | the croissant | 🥐
der Zucker | شەکر | دێر تسوکەر | the sugar | 🍬
die Brezel | بریتسل | دی برێتسل | the pretzel | 🥨
""", """
Was darf es sein? | هوین چ دخوازن؟ | What can I get you?
Sechs Brötchen, bitte. | شەش سەموون، هیڤیە. | Six rolls, please.
Das Brot ist ganz frisch. | نان گەلەک تازەیە. | The bread is very fresh.
Noch etwas? | تشتەکێ دی؟ | Anything else?
Wir öffnen um sechs Uhr. | ئەم دەمژمێر شەش ڤەدکەین. | We open at six.
"""),
 ("werkstatt", "🚗", "مێکانیکێ ترومبێلان", "Autowerkstatt", "Car workshop", """
die Werkstatt | گەراج | دی ڤێرکشتات | the workshop | 🏭
der Reifen | تایە | دێر ڕایفن | the tyre | 🛞
der Motor | مەکینە | دێر مۆتۆر | the engine | ⚙️
das Öl | زەیت | داس ئۆل | the oil | 🛢️
die Bremse | بریک | دی برێمزە | the brake | 🛑
die Batterie | پاتری | دی باتەری | the battery | 🔋
der Schraubenschlüssel | سپانە | دێر شراوبنشلووسل | the wrench | 🔧
das Licht | گلۆپ | داس لیشت | the light | 💡
reparieren | چاککرن | ڕێپاریرن | to repair | 🛠️
das Lenkrad | سەکان | داس لێنکرات | the steering wheel | 🎯
""", """
Was ist kaputt? | چ خەراب بوویە؟ | What's broken?
Die Bremsen sind alt. | بریک کەڤن بووینە. | The brakes are old.
Wir wechseln das Öl. | ئەم زەیتێ دگوهۆڕین. | We'll change the oil.
Das Auto ist morgen fertig. | ترومبێل سوبەهی ئامادە دبیت. | The car will be ready tomorrow.
Der Reifen hat keine Luft. | با د تایەی دا نینە. | The tyre has no air.
"""),
]

def rows(block, n):
    out = []
    for line in block.strip().splitlines():
        p = [x.strip() for x in line.split('|')]
        assert len(p) == n, line
        out.append(p)
    return out


import sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from extra import EXTRA  # noqa: E402

data = {"version": 2, "jobs": []}
for jid, emo, ku, de, en, words, phrases in JOBS:
    items = []
    for k, (wde, wku, hint, wen, wemo) in enumerate(rows(words, 5)):
        items.append({"id": f"job_{jid}_w{k}", "de": wde, "ku": wku, "kuLat": "", "deHint": hint, "en": wen, "emoji": wemo})
    for k, (pde, pku, pen) in enumerate(rows(phrases, 3)):
        items.append({"id": f"job_{jid}_p{k}", "de": pde, "ku": pku, "kuLat": "", "deHint": "", "en": pen, "emoji": "", "phrase": True})
    # ➕ قۆناغێن زێدە: ٥ ناڤ (قۆناغا ١) + ١٠ کار/ڕەنگدان (قۆناغا ٢)، ٧ رستە، دیالۆگ
    xw, xp, xd = EXTRA[jid]
    words = [it for it in items if not it.get("phrase")]
    phrases = [it for it in items if it.get("phrase")]
    for k, (wde, wku, hint, wen, wemo) in enumerate(rows(xw, 5)):
        words.append({"id": f"job_{jid}_w{10 + k}", "de": wde, "ku": wku, "kuLat": "", "deHint": hint, "en": wen, "emoji": wemo})
    for k, (pde, pku, pen) in enumerate(rows(xp, 3)):
        phrases.append({"id": f"job_{jid}_p{5 + k}", "de": pde, "ku": pku, "kuLat": "", "deHint": "", "en": pen, "emoji": "", "phrase": True})
    dialog = [{"id": f"job_{jid}_d{k}", "who": who, "de": dde, "ku": dku, "kuLat": "", "deHint": "", "en": "", "emoji": "", "dialog": True}
              for k, (who, dde, dku) in enumerate(rows(xd, 3))]
    assert len(words) == 25 and len(phrases) == 12 and 6 <= len(dialog) <= 8, (jid, len(words), len(phrases), len(dialog))
    data["jobs"].append({"id": jid, "emoji": emo, "ku": ku, "de": de, "en": en, "items": words + phrases + dialog,
                         "stages": [[w["id"] for w in words[:15]], [w["id"] for w in words[15:]], [p["id"] for p in phrases], [d["id"] for d in dialog]]})

(ROOT / "assets/jobs.json").write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(len(data["jobs"]), "jobs,", sum(len(j["items"]) for j in data["jobs"]), "items")
ids = [i["id"] for j in data["jobs"] for i in j["items"]]; assert len(ids) == len(set(ids))
