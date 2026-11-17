"""💼 پەیڤێن کاری — قۆناغێن زێدە: ٥ ناڤ + ١٠ کار/ڕەنگدان، ٧ رستە، دیالۆگ"""
EXTRA = {
"supermarkt": ("""
der Kassierer | کاشێر | دێر کاسیرەر | the cashier | 🧑‍💼
das Kleingeld | پارێن ورد | داس کلاینگێلت | the change | 🪙
der Korb | زەمبیل | دێر کۆرب | the basket | 🧺
die Kühltruhe | فریزەر | دی کوولترووە | the freezer | 🧊
die Flasche | شووشە | دی فلاشە | the bottle | 🍾
bezahlen | پارە دان | بەتسالن | to pay | 💳
kaufen | کڕین | کاوفن | to buy | 🛍️
suchen | لێگەڕیان | زووخن | to look for | 🔎
einräumen | ڕێکخستن ل سەر ڕەفکان | ئاینڕۆیمەن | to stock the shelves | 📥
kosten | بها هەبوون | کۆستن | to cost | 🏷️
billig | ئەرزان | بیلیش | cheap | 👍
teuer | گران (بها) | تۆیەر | expensive | 💸
frisch | تازە | فریش | fresh | 🌿
geöffnet | ڤەکری | گەئۆفنەت | open | 🔓
geschlossen | گرتی | گەشلۆسن | closed | 🔒
""", """
Wo finde ich den Reis? | برنج ل کیڤەیە؟ | Where can I find the rice?
Haben Sie eine Kundenkarte? | ئەرێ کارتا کڕیاران ل نک هەوە هەیە؟ | Do you have a loyalty card?
Ich brauche Kleingeld. | پێدڤیا من ب پارێن ورد هەیە. | I need change.
Hier ist Ihr Kassenbon. | ئەڤە پسوولا هەوە یە. | Here is your receipt.
Die Kasse zwei ist geöffnet. | سندووقا دوو ڤەکرییە. | Checkout two is open.
Das ist heute im Angebot. | ئەڤە ئەڤرۆ ب داشکاندنێ یە. | This is on sale today.
Einen schönen Tag noch! | ڕۆژەکا خۆش بۆ هەوە! | Have a nice day!
""", """
Kassierer | Guten Tag! Haben Sie eine Kundenkarte? | ڕۆژ باش! ئەرێ کارتا کڕیاران ل نک هەوە هەیە؟
Kundin | Nein, leider nicht. | نە، مخابن نینە.
Kassierer | Das macht zwölf Euro fünfzig. | ئەڤە دبیتە دوازدە یۆرۆ و پێنجی سەنت.
Kundin | Kann ich mit Karte bezahlen? | ئەرێ دشێم ب کارتێ پارەی بدەم؟
Kassierer | Ja, natürlich. Möchten Sie eine Tüte? | بەلێ، هەلبەت. ئەرێ کیسەکێ دخوازن؟
Kundin | Ja, bitte. Danke schön! | بەلێ، هیڤیە. گەلەک سوپاس!
"""),
"hausmeister": ("""
der Müllcontainer | سەتلێ زبلی یێ مەزن | دێر موولکۆنتەینەر | the trash container | 🗑️
die Schraube | بڕغی | دی شراوبە | the screw | 🔩
der Keller | ژێرزەمین | دێر کێلەر | the basement | 🏚️
das Fenster | پەنجەرە | داس فێنستەر | the window | 🪟
der Garten | باخچە | دێر گارتن | the garden | 🌳
reparieren | چاککرن | ڕێپاریرن | to repair | 🛠️
wechseln | گوهۆڕین | ڤێکسلن | to change | 🔄
prüfen | پشکنین | پرووفن | to check | ✅
streichen | ڕەنگ کرن | شترایشن | to paint (a wall) | 🖌️
tropfen | دلۆپ دلۆپ هاتن | ترۆپفن | to drip | 💧
laut | دەنگ بلند | لاوت | loud | 🔊
nass | تەڕ | ناس | wet | 💦
dringend | ب لەز | درینگەنت | urgent | ⚠️
fertig | تەمام | فێرتیش | finished | 🏁
sicher | ب ئەمان | زیشەر | safe | 🛡️
""", """
Der Wasserhahn tropft. | شێرێ ئاڤێ دلۆپ دکەت. | The tap is dripping.
Ich wechsle die Lampe. | ئەز گلۆپێ دگوهۆڕم. | I'm changing the lamp.
Wann haben Sie Zeit? | کەنگی دەمێ هەوە هەیە؟ | When do you have time?
Bitte rufen Sie den Hausmeister an. | هیڤیە تەلەفۆنێ بۆ هەستای بکەن. | Please call the caretaker.
Das ist dringend. | ئەڤە ب لەزە. | This is urgent.
Die Arbeit ist fertig. | کار تەمام بوو. | The work is done.
Der Müll kommt in den Container. | زبل دچیتە ناڤ سەتلێ مەزن. | The trash goes in the container.
""", """
Mieterin | Guten Morgen! Meine Heizung ist kaputt. | سپێدە باش! ئامیرێ گەرمکرنا من خەراب بوویە.
Hausmeister | Oh, das ist nicht gut. Seit wann? | ئۆه، ئەڤە نە باشە. ژ کەنگی ڤە؟
Mieterin | Seit gestern. Es ist sehr kalt. | ژ دوهی ڤە. گەلەک سارە.
Hausmeister | Ich komme heute um zwei Uhr. | ئەز ئەڤرۆ دەمژمێر دوو دێ هێم.
Mieterin | Super, vielen Dank! | زۆر باشە، گەلەک سوپاس!
Hausmeister | Gern geschehen. Bis später! | سەرچاڤان. هەتا پاشتر!
"""),
"krankenhaus": ("""
der Arm | باسک | دێر ئارم | the arm | 💪
das Bein | پێ | داس باین | the leg | 🦵
die Station | بەش (ل نەخۆشخانێ) | دی شتاتسیۆن | the ward | 🏨
der Verband | پێچان | دێر فێربانت | the bandage | 🩹
die Nachtschicht | دەواما شەڤێ | دی ناختشیشت | the night shift | 🌙
messen | پیڤان | مێسن | to measure | 📏
helfen | هاریکاری کرن | هێلفن | to help | 🤝
liegen | ڕاکشیان | لیگن | to lie down | 🛌
aufstehen | ڕابوون | ئاوفشتێەن | to get up | 🧍
wehtun | ئێشان | ڤێتوون | to hurt | 😣
müde | وەستیای | موودە | tired | 🥱
gesund | ساخلەم | گەزوونت | healthy | 💚
ruhig | ئارام | ڕوویش | calm | 😌
warm | گەرم | ڤارم | warm | ♨️
kalt | سار | کالت | cold | 🥶
""", """
Wo tut es weh? | کیڤە دئێشیت؟ | Where does it hurt?
Bitte bleiben Sie im Bett. | هیڤیە ل تەختێ بمینن. | Please stay in bed.
Der Arzt kommt gleich. | دکتۆر نوکە دهێت. | The doctor is coming soon.
Haben Sie gut geschlafen? | ئەرێ هوین باش نڤستن؟ | Did you sleep well?
Ich wechsle den Verband. | ئەز پێچانێ دگوهۆڕم. | I'm changing the bandage.
Sie dürfen heute nach Hause. | ئەڤرۆ دشێن بچنە مالێ. | You can go home today.
Klingeln Sie, wenn Sie etwas brauchen. | ئەگەر تشتەک پێدڤی بوو، زەنگێ لێ بدەن. | Ring if you need something.
""", """
Pfleger | Guten Morgen, Frau Berger! Wie geht es Ihnen? | سپێدە باش خاتوو بێرگەر! هوین چاوانن؟
Patientin | Nicht so gut. Mein Bein tut weh. | نە گەلەک باش. پێیێ من دئێشیت.
Pfleger | Ich messe jetzt Fieber. | نوکە ئەز تایا هەوە دپیڤم.
Patientin | Habe ich Fieber? | ئەرێ تا ل من هەیە؟
Pfleger | Nein, alles ist gut. Der Arzt kommt gleich. | نە، هەمی تشت باشە. دکتۆر نوکە دهێت.
Patientin | Danke, Sie sind sehr nett. | سوپاس، هوین گەلەک باشن.
"""),
"arztpraxis": ("""
der Rücken | پشت | دێر ڕووکن | the back | 🦴
der Hals | گەروو | دێر هالس | the throat | 🗣️
der Husten | کۆخک | دێر هووستن | the cough | 😷
die Sprechstunde | دەمێ دیتنا دکتۆری | دی شپرێششتوندە | the office hours | 🕘
die Überweisung | ڕەوانەکرن بۆ دکتۆرەکێ دی | دی ئووبەرڤایزونگ | the referral | 📨
untersuchen | پشکنینا لەشی | ئونتەرزووخن | to examine | 🩻
anrufen | تەلەفۆن کرن | ئانڕوفن | to call | 📞
warten | چاڤەڕێ کرن | ڤارتن | to wait | ⏳
husten | کۆخین | هووستن | to cough | 😮‍💨
nehmen | وەرگرتن | نێمن | to take | 🤲
besser | باشتر | بێسەر | better | 📈
schlimm | گران (خراب) | شلیم | bad (serious) | ⚠️
pünktlich | ل دەمێ خۆ | پوونکتلیش | on time | ⏰
nüchtern | ب زکێ ڤالا | نووشتەرن | on an empty stomach | 🍽️
dreimal täglich | ڕۆژێ سێ جاران | درایمال تێگلیش | three times a day | 3️⃣
""", """
Was fehlt Ihnen? | چ ل هەوە یە؟ | What's wrong?
Ich habe seit drei Tagen Husten. | ژ سێ ڕۆژان ڤە کۆخک ل من هەیە. | I've had a cough for three days.
Nehmen Sie die Tabletten dreimal täglich. | ڕۆژێ سێ جاران حەبان بخۆن. | Take the pills three times a day.
Ich schreibe Sie krank. | ئەز ڕاپۆرتا نەخۆشیێ بۆ هەوە دنڤیسم. | I'll give you a sick note.
Kommen Sie nächste Woche wieder. | هەفتا بێت دیسا وەرن. | Come back next week.
Bitte machen Sie den Oberkörper frei. | هیڤیە جلکێن سەری ژ خۆ بکەن. | Please undress your upper body.
Gute Besserung! | خودێ شیفایێ بدەت! | Get well soon!
""", """
Arzthelferin | Guten Tag! Haben Sie einen Termin? | ڕۆژ باش! ئەرێ ژڤانێ هەوە هەیە؟
Patient | Nein, aber ich habe starke Kopfschmerzen. | نە، بەلێ سەرئێشانەکا گران ل من هەیە.
Arzthelferin | Haben Sie Ihre Versichertenkarte? | ئەرێ کارتا بیمەیا هەوە دگەل هەوە یە؟
Patient | Ja, hier bitte. | بەلێ، ئەڤەیە.
Arzthelferin | Danke. Bitte warten Sie im Wartezimmer. | سوپاس. هیڤیە ل ژوورا چاڤەڕێکرنێ چاڤەڕێ بکەن.
Patient | Wie lange muss ich warten? | دڤێت چەند چاڤەڕێ بکەم؟
Arzthelferin | Ungefähr zwanzig Minuten. | نێزیکی بیست خولەکان.
"""),
"kita": ("""
die Gruppe | گرووپ | دی گرووپە | the group | 👫
das Mittagessen | خوارنا نیڤرۆ | داس میتاگئێسن | the lunch | 🍝
die Jacke | چاکێت | دی یاکە | the jacket | 🧥
der Stift | قەلەم | دێر شتیفت | the crayon | 🖍️
das Lied | ستران | داس لیت | the song | 🎵
spielen | یاری کرن | شپیلن | to play | 🎲
singen | ستران گۆتن | زینگن | to sing | 🎤
weinen | گری | ڤاینن | to cry | 😢
abholen | ژ جهەکی بردن | ئاپهۆلن | to pick up | 🚸
anziehen | جل کرنە بەر | ئانتسیەن | to put on (clothes) | 👕
lustig | خۆش (پێکەنینی) | لوستیش | funny | 😂
leise | هێدی (بێدەنگ) | لایزە | quiet | 🤫
traurig | خەمگین | تراوریش | sad | 😟
vorsichtig | ب ئاگەهداری | فۆرزیشتیش | careful | ⚠️
krank | نەخۆش | کرانک | sick | 🤒
""", """
Zieh bitte deine Jacke an. | هیڤیە چاکێتا خۆ بکە بەر خۆ. | Please put on your jacket.
Wer möchte malen? | کێ دخوازیت وێنەیان بکێشیت؟ | Who wants to paint?
Wir singen jetzt ein Lied. | نوکە ئەم سترانەکێ دبێژین. | Now we'll sing a song.
Warum weinst du? | بۆچی دگری؟ | Why are you crying?
Ihr Kind hat heute gut gegessen. | زارۆکێ هەوە ئەڤرۆ باش خوار. | Your child ate well today.
Ihr Kind hat Fieber. Bitte holen Sie es ab. | تا ل زارۆکێ هەوە هەیە. هیڤیە وەرن و ببەن. | Your child has a fever. Please pick them up.
Vorsicht, langsam! | ئاگەهدار بە، هێدی! | Careful, slowly!
""", """
Erzieherin | Guten Tag! Sie sind der Papa von Bnar, oder? | ڕۆژ باش! هوین بابێ بنارینە، وەسا نینە؟
Vater | Ja, genau. Wie war sein Tag? | بەلێ، دروستە. ڕۆژا وی چاوا بوو؟
Erzieherin | Sehr gut! Er hat viel gespielt und gemalt. | زۆر باش! وی گەلەک یاری کرن و وێنە کێشان.
Vater | Hat er auch gegessen? | ئەرێ خوارن ژی خوار؟
Erzieherin | Ja, er hat alles gegessen. | بەلێ، وی هەمی خوار.
Vater | Super! Danke und bis morgen! | زۆر باشە! سوپاس و هەتا سوبەهی!
"""),
"altenpflege": ("""
das Zimmer | ژوور | داس تسیمەر | the room | 🚪
die Decke | بەتانی | دی دێکە | the blanket | 🛏️
der Blutdruck | فشارا خوینێ | دێر بلووتدروک | the blood pressure | 🩺
die Hand | دەست | دی هانت | the hand | ✋
das Getränk | ڤەخوارن | داس گەترێنک | the drink | 🧃
anziehen | جل کرنە بەر | ئانتسیەن | to dress | 👚
duschen | خۆ شویشتن | دووشن | to shower | 🚿
essen | خوارن | ئێسن | to eat | 🍽️
vorlesen | خواندن بۆ کەسەکی | فۆرلێزن | to read aloud | 📖
sich setzen | ڕوینشتن | زیش زێتسن | to sit down | 🪑
langsam | هێدی | لانگزام | slowly | 🐢
schwach | لاواز | شڤاخ | weak | 🪫
allein | ب تنێ | ئالاین | alone | 🧍
freundlich | ڕوو خۆش | فرۆیندلیش | friendly | 😊
vergesslich | ژبیرکەر | فێرگێسلیش | forgetful | 🤔
""", """
Ich messe jetzt Ihren Blutdruck. | نوکە ئەز فشارا خوینا هەوە دپیڤم. | I'm measuring your blood pressure now.
Ist Ihnen kalt? | ئەرێ هوین هەست ب سەرمایێ دکەن؟ | Are you cold?
Möchten Sie eine Decke? | ئەرێ بەتانیەکێ دخوازن؟ | Would you like a blanket?
Langsam, ich helfe Ihnen. | هێدی، ئەز هاریکاریا هەوە دکەم. | Slowly, I'll help you.
Ihre Tochter kommt heute zu Besuch. | کچا هەوە ئەڤرۆ دێ هێتە سەرەدانێ. | Your daughter is visiting today.
Soll ich Ihnen die Zeitung vorlesen? | ئەرێ ڕۆژنامێ بۆ هەوە بخوینم؟ | Shall I read the newspaper to you?
Bitte trinken Sie noch ein Glas Wasser. | هیڤیە پەرداخەکێ دی ئاڤێ ڤەخۆن. | Please drink another glass of water.
""", """
Pflegerin | Guten Morgen, Herr Mohammed! Wie geht es Ihnen heute? | سپێدە باش کاک محەمەد! ئەڤرۆ هوین چاوانن؟
Herr Mohammed | Ach, ich bin ein bisschen müde. | ئاخ، ئەز هندەکێ وەستیامە.
Pflegerin | Möchten Sie jetzt frühstücken? | ئەرێ نوکە دخوازن تێشتێ بخۆن؟
Herr Mohammed | Ja, gern. Aber zuerst einen Tee, bitte. | بەلێ، ب دلخۆشی. بەلێ پێشی چایەک، هیڤیە.
Pflegerin | Kein Problem. Ich helfe Ihnen beim Aufstehen. | کێشە نینە. ئەز هاریکاریا هەوە دکەم دا ڕابن.
Herr Mohammed | Danke, Sie sind ein Engel. | سوپاس، هوین فریشتەنە.
"""),
"restaurant": ("""
die Suppe | شۆربە | دی زوپە | the soup | 🍜
der Nachtisch | شیرینی پشتی خوارنێ | دێر ناختیش | the dessert | 🍨
die Gabel | چەتال | دی گابل | the fork | 🍴
das Messer | کێر | داس مێسەر | the knife | 🔪
die Reservierung | گرتنا جهی | دی ڕێزێرڤیرونگ | the reservation | 📅
servieren | پێشکێشکرن | زێرڤیرن | to serve | 🛎️
kochen | لێنان | کۆخن | to cook | 🥘
empfehlen | پێشنیار کرن | ئێمپفێلن | to recommend | 👍
abräumen | کۆمکرنا قاپان | ئاپڕۆیمەن | to clear the table | 🧹
schmecken | تام هەبوون | شمێکن | to taste | 😋
lecker | خۆش (تام) | لێکەر | delicious | 🤤
scharf | تویژ | شارف | spicy | 🌶️
vegetarisch | بێ گۆشت | ڤێگەتاریش | vegetarian | 🥦
besetzt | گرتی | بەزێتست | taken (seat) | 🚫
frei | ڤالا | فرای | free | ✅
""", """
Haben Sie reserviert? | ئەرێ هەوە جه گرتییە؟ | Do you have a reservation?
Was können Sie empfehlen? | هوین چ پێشنیار دکەن؟ | What can you recommend?
Ich nehme die Suppe. | ئەز شۆربێ دخوازم. | I'll have the soup.
Ist das scharf? | ئەرێ ئەڤە تویژە؟ | Is this spicy?
Zusammen oder getrennt? | پێکڤە یان جودا؟ | Together or separately?
Stimmt so. | یا مای بۆ هەوە بیت. | Keep the change.
Guten Appetit! | نۆشی گیان بیت! | Enjoy your meal!
""", """
Kellner | Guten Abend! Haben Sie reserviert? | ئێڤاری باش! ئەرێ هەوە جه گرتییە؟
Gast | Ja, auf den Namen Duski, für zwei Personen. | بەلێ، ب ناڤێ دۆسکی، بۆ دوو کەسان.
Kellner | Bitte hier entlang. Was möchten Sie trinken? | هیڤیە ب ڤێ ڕێکێ وەرن. هوین دخوازن چ ڤەخۆن؟
Gast | Zwei Wasser, bitte. Was können Sie empfehlen? | دوو ئاڤ، هیڤیە. هوین چ پێشنیار دکەن؟
Kellner | Heute ist der Fisch sehr lecker. | ئەڤرۆ ماسی گەلەک خۆشە.
Gast | Gut, dann nehmen wir zweimal Fisch. | باشە، ئێدی دوو ماسیان دخوازین.
"""),
"lager": ("""
der Lieferschein | پسوولا گەهاندنێ | دێر لیفەرشاین | the delivery note | 📄
die Palette | پالێت | دی پالێتە | the pallet | 🟫
die Rampe | ڕامپا بارکرنێ | دی ڕامپە | the loading ramp | 🛻
der Chef | سەرکار | دێر شێف | the boss | 👔
die Pause | پشوو | دی پاوزە | the break | ☕
packen | تێکرن (ناڤ کارتۆنێ) | پاکن | to pack | 🎁
tragen | هەلگرتن | تراگن | to carry | 💪
laden | بارکرن | لادن | to load | 🚛
zählen | هژمارتن | تسێلن | to count | 🔢
scannen | سکان کرن | سکێنن | to scan | 📲
voll | تژی | فۆل | full | 🟩
leer | ڤالا | لێر | empty | ⬜
pünktlich | ل دەمێ خۆ | پوونکتلیش | on time | ⏰
vorsichtig | ب ئاگەهداری | فۆرزیشتیش | careful | ⚠️
schnell | ب لەز | شنێل | fast | ⚡
""", """
Der Lkw kommt um acht Uhr. | لۆری دەمژمێر هەشت دهێت. | The truck comes at eight.
Bitte scannen Sie alle Pakete. | هیڤیە هەمی پاکێتان سکان بکەن. | Please scan all packages.
Das Regal ist voll. | ڕەفک تژییە. | The shelf is full.
Wir haben jetzt Pause. | نوکە پشووا مە یە. | We have a break now.
Hier fehlt ein Karton. | ل ڤێرێ کارتۆنەک کێمە. | A box is missing here.
Vorsicht, das ist zerbrechlich! | ئاگەهدار بە، ئەڤە دشکێت! | Careful, this is fragile!
Kannst du mir helfen? | دشێی هاریکاریا من بکەی؟ | Can you help me?
""", """
Chef | Guten Morgen, Zana! Heute kommen drei Lieferungen. | سپێدە باش زانا! ئەڤرۆ سێ گەهاندن دێ هێن.
Zana | Guten Morgen! Wann kommt die erste? | سپێدە باش! یا ئێکێ کەنگی دهێت؟
Chef | Um acht Uhr. Bitte scanne alle Pakete. | دەمژمێر هەشت. هیڤیە هەمی پاکێتان سکان بکە.
Zana | Okay. Wo soll ich die Kartons hinstellen? | باشە. ئەز کارتۆنان ل کیڤە دانم؟
Chef | Ins Regal C, ganz oben. | ل ڕەفکا C، ل سەری سەری.
Zana | Alles klar! | هەمی ڕوونە!
"""),
"reinigung": ("""
der Lappen | پەڕۆک | دێر لاپن | the cloth | 🧻
das Putzmittel | مادێ پاقژکرنێ | داس پوتسمیتل | the cleaning product | 🧴
der Wischmopp | مۆپ | دێر ڤیشمۆپ | the mop | 🫧
die Handschuhe | دەستکێش | دی هانتشووە | the gloves | 🧤
das Büro | نڤیسینگەهـ | داس بوورۆ | the office | 🏢
wischen | پاقژکرن ب پەڕۆکێ | ڤیشن | to wipe | 🖐️
saugen | پاقژکرن ب ماکینێ | زاوگن | to vacuum | 💨
spülen | شویشتنا قاپان | شپوولن | to wash up | 🍽️
aufräumen | ڕێکخستن | ئاوفڕۆیمەن | to tidy up | 🗂️
leeren | ڤالاکرن | لێرن | to empty | ⬇️
nass | تەڕ | ناس | wet | 💦
trocken | هشک | ترۆکن | dry | ☀️
glatt | خلیسۆک | گلات | slippery | ⚠️
fertig | تەمام | فێرتیش | done | 🏁
gründlich | ب باشی | گروونتلیش | thoroughly | 🔍
""", """
Vorsicht, der Boden ist glatt! | ئاگەهدار بە، ئەرد خلیسۆکە! | Careful, the floor is slippery!
Ich sauge jetzt das Büro. | نوکە ئەز نڤیسینگەهێ ب ماکینێ پاقژ دکەم. | I'm vacuuming the office now.
Wo sind die Putzmittel? | مادێن پاقژکرنێ ل کیڤەنە؟ | Where are the cleaning products?
Die Mülleimer sind schon leer. | سەتلێن زبلی ڤالانە. | The bins are already empty.
Ich bin in einer Stunde fertig. | ئەز پشتی دەمژمێرەکێ تەمام دبم. | I'll be done in an hour.
Bitte nicht betreten! | هیڤیە پێ نەکەنە سەر! | Please don't step here!
Darf ich hier putzen? | ئەرێ دشێم ل ڤێرێ پاقژ بکەم؟ | May I clean here?
""", """
Chefin | Hallo Dilhin! Heute putzt du bitte den zweiten Stock. | سلاڤ دیلهین! ئەڤرۆ هیڤیە قاتا دووێ پاقژ بکە.
Dilhin | Gern. Die Büros und die Toiletten? | ب دلخۆشی. نڤیسینگەهـ و تەوالێت؟
Chefin | Ja, und bitte auch die Fenster. | بەلێ، و هیڤیە پەنجەرەیان ژی.
Dilhin | Wo finde ich neue Putzmittel? | مادێن پاقژکرنێ یێن نوو ل کیڤە دبینم؟
Chefin | Im Keller, im kleinen Raum links. | ل ژێرزەمینێ، ل ژوورا بچووک ل لایێ چەپێ.
Dilhin | Danke! Ich bin um zwölf Uhr fertig. | سوپاس! ئەز دەمژمێر دوازدە تەمام دبم.
"""),
"friseur": ("""
das Shampoo | شامپۆ | داس شامپو | the shampoo | 🧴
die Farbe | ڕەنگ | دی فاربە | the colour | 🎨
der Pony | پرچا سەر ناڤچاڤان | دێر پۆنی | the fringe | 💇‍♀️
die Seite | ڕەخ | دی زایتە | the side | ↔️
der Nacken | پشتا ستووی | دێر ناکن | the back of the neck | 🔙
waschen | شویشتن | ڤاشن | to wash | 🚿
färben | ڕەنگ کرن | فێربن | to dye | 🖌️
föhnen | هشککرن ب سێشوارێ | فۆنن | to blow-dry | 🌬️
rasieren | ڕیهـ تاشین | ڕازیرن | to shave | 🫧
kämmen | شە کرن | کێمن | to comb | 🪮
modern | مۆدێرن | مۆدێرن | modern | ✨
dünn | تەنک | دوون | thin | ➖
dick | ستوور | دیک | thick | ➕
glatt | ڕاست (پرچ) | گلات | straight (hair) | 📐
lockig | لوول | لۆکیش | curly | ➰
""", """
Waschen und schneiden, bitte. | شویشتن و بڕین، هیڤیە. | Wash and cut, please.
An den Seiten kurz, oben etwas länger. | ل ڕەخان کورت، ل سەری هندەکێ درێژتر. | Short on the sides, a bit longer on top.
Möchten Sie einen Termin? | ئەرێ هوین ژڤانەکێ دخوازن؟ | Would you like an appointment?
Ist das Wasser zu heiß? | ئەرێ ئاڤ گەلەک گەرمە؟ | Is the water too hot?
Soll ich den Bart auch rasieren? | ئەرێ ڕیهێ ژی بتاشم؟ | Shall I shave the beard too?
Schauen Sie in den Spiegel. | ل نەینکێ بنێڕن. | Look in the mirror.
Bis zum nächsten Mal! | هەتا جارا بێت! | See you next time!
""", """
Friseur | Hallo! Was darf ich für dich machen? | سلاڤ! ئەز چ بۆ تە بکەم؟
Safin | Einmal Haare schneiden, bitte. | پرچ بڕین، هیڤیە.
Friseur | Wie kurz? | چەند کورت؟
Safin | An den Seiten kurz, oben etwas länger. | ل ڕەخان کورت، ل سەری هندەکێ درێژتر.
Friseur | Und den Bart? | و ڕیهـ؟
Safin | Nur ein bisschen kürzer, bitte. | تنێ هندەکێ کورتتر، هیڤیە.
"""),
"fahrer": ("""
die Hausnummer | ژمارا خانی | دی هاوسنومەر | the house number | 🔢
der Stau | قەرەبالغیا ڕێکێ | دێر شتاو | the traffic jam | 🚥
die Unterschrift | ئیمزا | دی ئونتەرشریفت | the signature | ✍️
der Parkplatz | جهێ ڕاگرتنا ترومبێلێ | دێر پارکپلاتس | the parking space | 🅿️
die Kreuzung | چوارڕێک | دی کرۆیتسونگ | the crossroads | ✖️
fahren | لێخوڕین | فارن | to drive | 🚘
liefern | گەهاندن | لیفەرن | to deliver | 📦
parken | ڕاگرتنا ترومبێلێ | پارکن | to park | 🛑
abbiegen | زڤڕین بۆ لایەکی | ئاپبیگن | to turn | ↪️
klingeln | زەنگ لێدان | کلینگلن | to ring the bell | 🔔
spät | درەنگ | شپێت | late | 🕙
früh | زوو | فرووە | early | 🌅
weit | دوور | ڤایت | far | 🗺️
nah | نێزیک | نا | near | 🎯
pünktlich | ل دەمێ خۆ | پوونکتلیش | on time | ⏰
""", """
Ich habe ein Paket für Herrn Hamid. | پاکێتەک بۆ کاک حەمید ل نک من هەیە. | I have a package for Mr Hamid.
Er ist nicht zu Hause. | ئەو ل مالێ نینە. | He isn't at home.
Kann ich das Paket beim Nachbarn lassen? | ئەرێ دشێم پاکێتێ ل نک جیرانی بهێلم؟ | Can I leave the package with the neighbour?
Es gibt einen Stau auf der Autobahn. | ل سەر ڕێکا گشتی قەرەبالغی هەیە. | There's a traffic jam on the motorway.
Biegen Sie an der Kreuzung rechts ab. | ل چوارڕێکێ بزڤڕنە لایێ ڕاستێ. | Turn right at the crossroads.
Ich bin in fünf Minuten da. | ئەز پشتی پێنج خولەکان دگەهم. | I'll be there in five minutes.
Wo kann ich hier parken? | ل ڤێرێ ل کیڤە دشێم ترومبێلێ ڕاگرم؟ | Where can I park here?
""", """
Metin | Guten Tag! Ein Paket für Frau Huda Koçer. | ڕۆژ باش! پاکێتەک بۆ خاتوو هوودا کۆچەر.
Kundin | Das bin ich. Danke! | ئەو ئەزم. سوپاس!
Metin | Bitte unterschreiben Sie hier. | هیڤیە ل ڤێرێ ئیمزا بکەن.
Kundin | Hier? Okay. | ل ڤێرێ؟ باشە.
Metin | Danke. Haben Sie noch ein Paket für die Post? | سوپاس. ئەرێ پاکێتەکێ دی بۆ پۆستێ هەیە؟
Kundin | Nein, heute nicht. Schönen Tag noch! | نە، ئەڤرۆ نە. ڕۆژەکا خۆش!
"""),
"bau": ("""
der Sand | خیز | دێر زانت | the sand | 🟨
das Dach | بان | داس داخ | the roof | 🛖
die Säge | مشار | دی زێگە | the saw | 🪚
die Schubkarre | عەرەبانا دەستی | دی شووپکارە | the wheelbarrow | 🛞
der Vorarbeiter | سەرکار | دێر فۆرئاربایتەر | the foreman | 👷
bauen | ئاڤاکرن | باوەن | to build | 🏘️
bohren | کون کرن | بۆرن | to drill | 🕳️
mischen | تێکەل کرن | میشن | to mix | 🌀
messen | پیڤان | مێسن | to measure | 📏
heben | بلند کرن | هێبن | to lift | 🏋️
gefährlich | مەترسیدار | گەفێرلیش | dangerous | ☠️
schwer | گران | شڤێر | heavy | ⚖️
hoch | بلند | هۆخ | high | 🔝
gerade | ڕاست | گەرادە | straight | 📐
fertig | تەمام | فێرتیش | finished | 🏁
""", """
Wir fangen um sieben Uhr an. | ئەم دەمژمێر حەفت دەست پێ دکەین. | We start at seven.
Bitte bring mir die Säge. | هیڤیە مشارێ بۆ من بینە. | Please bring me the saw.
Wie viel Sand brauchen wir? | چەند خیز پێدڤی یە؟ | How much sand do we need?
Die Wand ist nicht gerade. | دیوار نە ڕاستە. | The wall isn't straight.
Das ist zu schwer für eine Person. | ئەڤە بۆ ئێک کەسی گەلەک گرانە. | That's too heavy for one person.
Der Vorarbeiter kommt gleich. | سەرکار نوکە دهێت. | The foreman is coming soon.
Feierabend! Bis morgen. | کار ب دوماهی هات! هەتا سوبەهی. | Done for today! See you tomorrow.
""", """
Vorarbeiter | Morgen, Hamid! Heute bauen wir die Wand im ersten Stock. | سپێدە باش حەمید! ئەڤرۆ ئەم دیوارێ قاتا ئێکێ ئاڤا دکەین.
Hamid | Okay. Brauchen wir noch Zement? | باشە. ئەرێ هێشتا چیمەنتۆ پێدڤی یە؟
Vorarbeiter | Ja, zehn Säcke. Sie sind im Container. | بەلێ، دەهـ کیس. ئەو ل ناڤ کۆنتەینەرێ نە.
Hamid | Die Säcke sind schwer. Kann mir jemand helfen? | کیس گرانن. ئەرێ کەسەک دشێت هاریکاریا من بکەت؟
Vorarbeiter | Ja, Zana hilft dir. Und trag bitte deinen Helm! | بەلێ، زانا هاریکاریا تە دکەت. و هیڤیە کلاڤێ خۆ بکە سەرێ خۆ!
Hamid | Natürlich, Chef! | هەلبەت، سەرکار!
"""),
"baeckerei": ("""
der Teig | هەویر | دێر تایک | the dough | 🥣
die Torte | کێکا مەزن | دی تۆرتە | the gateau | 🎂
das Vollkornbrot | نانێ گەنمێ تەمام | داس فۆلکۆرنبرۆت | the wholemeal bread | 🟫
die Butter | کەرە | دی بوتەر | the butter | 🧈
das Ei | هێک | داس ئای | the egg | 🥚
schneiden | بڕین | شنایدن | to slice | 🔪
verkaufen | فرۆتن | فێرکاوفن | to sell | 💰
einpacken | پێچان | ئاینپاکن | to wrap | 🎁
probieren | تام کرن | پرۆبیرن | to taste | 👅
bestellen | داخوازکرن | بەشتێلن | to order | 📝
warm | گەرم | ڤارم | warm | ♨️
süß | شرین | زووس | sweet | 🍭
knusprig | کراسپی | کنوسپریش | crispy | ✨
weich | نەرم | ڤایش | soft | ☁️
alt | کەڤن | ئالت | old (stale) | 🕰️
""", """
Ist das Brot von heute? | ئەرێ ئەڤ نانە یێ ئەڤرۆ یە؟ | Is this bread from today?
Möchten Sie es geschnitten? | ئەرێ دخوازن بهێتە بڕین؟ | Would you like it sliced?
Ich möchte eine Torte bestellen. | ئەز دخوازم کێکەکا مەزن داخواز بکەم. | I'd like to order a gateau.
Für wann brauchen Sie die Torte? | کێکێ بۆ کەنگی دخوازن؟ | When do you need the cake?
Die Brötchen sind noch warm. | سەموون هێشتا گەرمن. | The rolls are still warm.
Zum Mitnehmen oder hier essen? | بۆ بردنێ یان ل ڤێرێ دخۆن؟ | To take away or eat here?
Das macht drei Euro zwanzig. | ئەڤە دبیتە سێ یۆرۆ و بیست سەنت. | That's three euros twenty.
""", """
Verkäuferin | Guten Morgen! Was darf es sein? | سپێدە باش! هوین چ دخوازن؟
Samad | Guten Morgen! Vier Brötchen und ein Vollkornbrot, bitte. | سپێدە باش! چوار سەموون و نانەکێ گەنمێ تەمام، هیڤیە.
Verkäuferin | Möchten Sie das Brot geschnitten? | ئەرێ دخوازن نان بهێتە بڕین؟
Samad | Ja, bitte. Und haben Sie Croissants? | بەلێ، هیڤیە. و ئەرێ کرواسان هەنە؟
Verkäuferin | Ja, ganz frisch! Wie viele? | بەلێ، گەلەک تازە! چەند؟
Samad | Zwei, bitte. Was macht das? | دوو، هیڤیە. هەمی ب چەندە؟
Verkäuferin | Das macht sieben Euro achtzig. | ئەڤە دبیتە حەفت یۆرۆ و هەشتێ سەنت.
"""),
"werkstatt": ("""
der Kofferraum | سندووقا ترومبێلێ | دێر کۆفەرڕاوم | the boot | 🧳
die Scheibe | جامێ ترومبێلێ | دی شایبە | the window glass | 🪟
der Kostenvoranschlag | خەملاندنا بهای | دێر کۆستنفۆرئانشلاک | the cost estimate | 🧮
der TÜV | پشکنینا فەرمی یا ترومبێلێ | دێر تووف | the vehicle inspection | ✅
das Ersatzteil | پارچا یەدەک | داس ئێرزاتستایل | the spare part | 🔩
wechseln | گوهۆڕین | ڤێکسلن | to change | 🔄
prüfen | پشکنین | پرووفن | to check | 🔍
waschen | شویشتن | ڤاشن | to wash | 🚿
abholen | بردن ژ گەراجێ | ئاپهۆلن | to collect | 🔑
bremsen | بریک گرتن | برێمزن | to brake | ⛔
laut | دەنگ بلند | لاوت | loud | 🔊
kaputt | خەراب | کاپوت | broken | 💥
neu | نوو | نۆی | new | 🆕
gebraucht | دەستێ دووێ | گەبراوخت | used | ♻️
teuer | گران | تۆیەر | expensive | 💸
""", """
Das Auto macht komische Geräusche. | ترومبێل دەنگێن نەئاسایی ددەت. | The car makes strange noises.
Wann ist das Auto fertig? | ترومبێل کەنگی ئامادە دبیت؟ | When will the car be ready?
Was kostet die Reparatur? | چاککرن ب چەندە؟ | What does the repair cost?
Wir brauchen ein Ersatzteil. | پێدڤیا مە ب پارچەکا یەدەک هەیە. | We need a spare part.
Ich mache Ihnen einen Kostenvoranschlag. | ئەز خەملاندنا بهای بۆ هەوە دکەم. | I'll give you a cost estimate.
Bitte lassen Sie den Schlüssel hier. | هیڤیە کلیلێ ل ڤێرێ بهێلن. | Please leave the key here.
Ihr Auto braucht neue Reifen. | ترومبێلا هەوە پێدڤی ب تایێن نوو هەیە. | Your car needs new tyres.
""", """
Mechaniker | Guten Tag! Was ist das Problem? | ڕۆژ باش! ئاریشە چیە؟
Poya | Mein Auto macht komische Geräusche beim Bremsen. | ترومبێلا من دەمێ بریکێ دەنگێن نەئاسایی ددەت.
Mechaniker | Ich schaue mal. Die Bremsen sind alt. | ئەز دێ بەرێ خۆ دەمێ. بریک کەڤن بووینە.
Poya | Was kostet die Reparatur? | چاککرن ب چەندە؟
Mechaniker | Ungefähr zweihundert Euro. Das Auto ist morgen fertig. | نێزیکی دوو سەد یۆرۆ. ترومبێل سوبەهی ئامادە دبیت.
Poya | Gut, dann bis morgen. | باشە، ئێدی هەتا سوبەهی.
"""),
}
