"""🎓 Goethe A1 Modelltest 2–5 ➔ assets/goethe.json («tests»)
Modelltest 1 = parts یێن سەری (وەکی خۆ دمینیت).
"""
import json, pathlib, copy
ROOT = pathlib.Path(__file__).resolve().parents[2]
P = ROOT / "assets/goethe.json"
d = json.loads(P.read_text(encoding="utf-8"))
base = d["parts"]
KU = {(pi, si): s["ku"] for pi, p in enumerate(base) for si, s in enumerate(p["sections"])}
REP = {(pi, si): s.get("repeat") for pi, p in enumerate(base) for si, s in enumerate(p["sections"])}
SPEAK1 = copy.deepcopy(base[3]["sections"][0]["items"][0])

def A(*lines):  # m: / f: ➔ audio
    out = []
    for ln in lines:
        g, t = ln.split(":", 1)
        out.append({"g": g.strip(), "t": t.strip()})
    return out

def mc(audio, q, opts, ans, ku, pics=None):
    it = {"t": "mc", "audio": audio, "q": q, "options": opts, "answer": ans, "ku": ku}
    if pics: it["pics"] = pics
    return it

def rf_a(audio, q, ans, ku): return {"t": "rf", "text": None, "audio": audio, "q": q, "answer": ans, "ku": ku}
def rf_t(text, q, ans, ku): return {"t": "rf", "text": text, "audio": None, "q": q, "answer": ans, "ku": ku}
def ab(q, a, b, ans, ku): return {"t": "ab", "q": q, "a": a, "b": b, "answer": ans, "ku": ku}

def sec(pi, si, title, items):
    s = {"title": title, "ku": KU[(pi, si)], "items": items}
    if REP.get((pi, si)): s["repeat"] = REP[(pi, si)]
    return s

def test(n, h1, h2, h3, l1, l2, l3, form, write, theme, cards2, cards3):
    parts = copy.deepcopy([{k: v for k, v in p.items() if k != "sections"} for p in base])
    parts[0]["sections"] = [sec(0, 0, "Teil 1", h1), sec(0, 1, "Teil 2", h2), sec(0, 2, "Teil 3", h3)]
    parts[1]["sections"] = [sec(1, 0, "Teil 1", l1), sec(1, 1, "Teil 2", l2), sec(1, 2, "Teil 3", l3)]
    parts[2]["sections"] = [sec(2, 0, "Teil 1", [form]), sec(2, 1, "Teil 2", [write])]
    sp2 = copy.deepcopy(base[3]["sections"][1]["items"][0]); sp2["theme"] = theme
    sp2["ku"] = f"ل سەر بابەتێ «{theme}» ب پەیڤا سەر کارتێ پرسیارەکێ بکە:"
    sp2["cards"] = [{"w": w, "ex": ex} for w, ex in cards2]
    sp3 = copy.deepcopy(base[3]["sections"][2]["items"][0])
    sp3["cards"] = [{"pic": p, "kw": kw, "ex": ex} for p, kw, ex in cards3]
    parts[3]["sections"] = [sec(3, 0, "Teil 1", [copy.deepcopy(SPEAK1)]), sec(3, 1, "Teil 2", [sp2]), sec(3, 2, "Teil 3", [sp3])]
    return {"id": f"t{n}", "title": f"Modelltest {n}", "parts": parts}

def form(text, ku, fields): return {"t": "form", "text": text, "ku": ku, "fields": [{"label": l, "answer": a} for l, a in fields]}
def write(task, ku, pts): return {"t": "write", "task": task, "ku": ku, "points": [{"de": de, "ku": k, "kw": kw} for de, k, kw in pts]}

T = []
# ───────────────────────── Modelltest 2 ─────────────────────────
_mail_a = "Hallo Samad,\nvielen Dank für deine E-Mail. Am Sonntag kann ich leider nicht kommen, meine Eltern besuchen mich. Aber am Samstagabend habe ich Zeit. Wollen wir zusammen kochen? Ich bringe Gemüse und Reis mit.\nLiebe Grüße\nDilhin"
_mail_b = "Liebe Kolleginnen und Kollegen,\nunser Büro ist vom 23. bis 27. Dezember geschlossen. Ab dem 28. Dezember sind wir wieder für Sie da. In dringenden Fällen rufen Sie bitte Frau Koçer an: 0176 556677.\nIhr Team"
T.append(test(2,
 [mc(A("m: Guten Tag, ich möchte eine Fahrkarte nach Köln.", "f: Einfach oder hin und zurück?", "m: Hin und zurück, bitte. Fährt der Zug um zehn?", "f: Nein, der Zug um zehn fällt heute aus. Der nächste fährt um Viertel nach zehn."), "Wann fährt der Zug?", ["10:00 Uhr", "10:15 Uhr", "10:45 Uhr"], 1, "شەمەندەفەر کەنگی دچیت؟"),
  mc(A("f: Was machst du am Wochenende? Gehst du schwimmen?", "m: Nein, es ist zu kalt. Ich spiele Fußball mit Metin."), "Was macht der Mann am Wochenende?", ["Schwimmen", "Fußball", "Fahrrad fahren"], 1, "زەلام دوماهیا هەفتێ چ دکەت؟", ["🏊", "⚽", "🚲"]),
  mc(A("m: Ich brauche noch Obst. Haben Sie Bananen?", "f: Bananen leider nicht mehr. Aber wir haben schöne Äpfel und Orangen.", "m: Dann nehme ich ein Kilo Orangen."), "Was kauft der Mann?", ["Bananen", "Äpfel", "Orangen"], 2, "زەلام چ دکڕیت؟", ["🍌", "🍎", "🍊"]),
  mc(A("f: Entschuldigung, wo finde ich die Toiletten?", "m: Im ersten Stock, neben dem Café. Nicht im Erdgeschoss."), "Wo sind die Toiletten?", ["Im Erdgeschoss", "Im ersten Stock", "Im zweiten Stock"], 1, "تەوالێت ل کیڤەنە؟"),
  mc(A("m: Nehmen wir heute das Fahrrad?", "f: Lieber nicht. Im Radio sagen sie, es regnet am Nachmittag."), "Wie ist das Wetter am Nachmittag?", ["Sonnig", "Regen", "Schnee"], 1, "پشتی نیڤرۆ کەشوهەوا چاوا یە؟", ["☀️", "🌧️", "❄️"]),
  mc(A("f: Wie viel kostet das T-Shirt?", "m: Normal kostet es zwanzig Euro, aber heute nur fünfzehn."), "Wie viel kostet das T-Shirt heute?", ["12 Euro", "15 Euro", "20 Euro"], 1, "ئەڤرۆ تیشێرت ب چەندە؟")],
 [rf_a(A("m: Liebe Fahrgäste, der Bus Linie zwölf fährt heute nicht bis zum Bahnhof. Bitte steigen Sie am Marktplatz um."), "Der Bus fährt heute bis zum Bahnhof.", False, "ئەڤرۆ پاس دچیتە وێستگەهێ."),
  rf_a(A("f: Achtung bitte: Heute ist unser Kaufhaus bis zweiundzwanzig Uhr geöffnet."), "Das Kaufhaus ist heute bis 22 Uhr offen.", True, "ئەڤرۆ بازار هەتا دەمژمێر ٢٢ ڤەکرییە."),
  rf_a(A("m: Information für die Fluggäste nach Istanbul: Ihr Flug hat dreißig Minuten Verspätung."), "Der Flug nach Istanbul ist pünktlich.", False, "فڕینا ئەستەنبوڵێ ل دەمێ خۆ یە."),
  rf_a(A("f: Liebe Kundinnen und Kunden, in der Obstabteilung sind heute alle Erdbeeren im Angebot."), "Die Erdbeeren sind heute billiger.", True, "ئەڤرۆ توو ئەرزانترن.")],
 [mc(A("f: Hallo Dilin, hier ist Mama. Ich komme heute später nach Hause, um acht. Das Essen ist im Kühlschrank."), "Wann kommt die Mutter nach Hause?", ["Um 6 Uhr", "Um 7 Uhr", "Um 8 Uhr"], 2, "دایک کەنگی دزڤڕیتە مالێ؟"),
  mc(A("m: Guten Tag, hier ist die Autowerkstatt Becker. Ihr Auto ist fertig. Sie können es morgen ab neun Uhr abholen."), "Wann kann man das Auto abholen?", ["Heute", "Morgen ab 9 Uhr", "Morgen ab 10 Uhr"], 1, "دشێی ترومبێلێ کەنگی ببەی؟"),
  mc(A("f: Hallo Poya, hier ist Avin. Bitte kauf noch Brot und Milch. Eier haben wir noch."), "Was soll Poya kaufen?", ["Brot und Eier", "Brot und Milch", "Milch und Eier"], 1, "دڤێت پۆیا چ بکڕیت؟"),
  mc(A("m: Hallo, hier ist Herr Weber von der Sprachschule. Der Kurs am Montag ist nicht in Raum drei, sondern in Raum fünf."), "In welchem Raum ist der Kurs?", ["Raum 3", "Raum 5", "Raum 8"], 1, "خول ل کیژ ژوورێ یە؟"),
  mc(A("f: Hi Metin, ich bin's, Huda. Wir gehen am Freitag nicht ins Kino, sondern essen Pizza. Kommst du mit?"), "Was machen sie am Freitag?", ["Ins Kino gehen", "Pizza essen", "Fußball spielen"], 1, "ئەو رۆژا ئەینیێ چ دکەن؟")],
 [rf_t(_mail_a, "Dilhin hat am Sonntag Besuch.", True, "دیلهین رۆژا یەکشەمبیێ میڤان هەنە."),
  rf_t(_mail_a, "Dilhin möchte am Samstag ins Restaurant gehen.", False, "دیلهین دخوازیت شەمبیێ بچیتە خوارنگەهێ."),
  rf_t(_mail_a, "Dilhin bringt Reis mit.", True, "دیلهین برنجی دگەل خۆ دئینیت."),
  rf_t(_mail_b, "Das Büro ist am 28. Dezember geöffnet.", True, "نڤیسینگەهـ رۆژا ٢٨ێ کانوونا ئێکێ ڤەکرییە."),
  rf_t(_mail_b, "Man soll in dringenden Fällen eine E-Mail schreiben.", False, "ل حالەتێن لەز دڤێت ئیمەیلەکێ بنڤیسی.")],
 [ab("Sie möchten am Samstagabend tanzen gehen.", "Disco Nachtflug – Fr + Sa ab 22 Uhr", "Tanzschule Weber – Kurse Mo–Fr 17–20 Uhr", "a", "دخوازی شەمبی ئێڤاری بچیە سەمایێ."),
  ab("Sie suchen ein günstiges Fahrrad.", "Fahrrad-Shop: neue E-Bikes ab 1.900 €", "Flohmarkt am Sonntag: gebrauchte Fahrräder ab 40 €", "b", "ل پایسکلەکا ئەرزان دگەڕێی."),
  ab("Ihr Kind ist krank. Sie brauchen am Sonntag einen Arzt.", "Kinderarzt Dr. Lang – Mo–Fr 8–18 Uhr", "Ärztlicher Notdienst – Sa, So und feiertags: 116 117", "b", "زارۆکێ تە نەخۆشە، یەکشەمبی پێدڤی ب دکتۆرەکی هەیە."),
  ab("Sie möchten Deutsch online lernen.", "Deutschkurs im Internet – lernen Sie zu Hause, wann Sie wollen", "Volkshochschule – Deutschkurse in Raum 4, Mo + Mi", "a", "دخوازی ئەلمانی ب ئینتەرنێتێ فێر ببی."),
  ab("Sie suchen eine Wohnung mit Balkon.", "2-Zimmer-Wohnung, 3. Stock, mit Balkon, 650 €", "1-Zimmer-Wohnung, Erdgeschoss, mit Garten, 480 €", "a", "ل خانیەکێ ب بالکۆن دگەڕێی.")],
 [rf_t("🏊 Hallenbad\nWegen Reparatur vom 1. bis 15. März geschlossen", "Am 10. März kann man hier schwimmen.", False, "رۆژا ١٠ێ ئادارێ دشێی ل ڤێرێ مەلەڤانیێ بکەی."),
  rf_t("🛗 Aufzug außer Betrieb\nBitte benutzen Sie die Treppe", "Man muss die Treppe nehmen.", True, "دڤێت پەیژەیێ بکاربینی."),
  rf_t("🍽️ Mittagstisch\nMo–Fr 12–14 Uhr\nSuppe + Hauptgericht 8,50 €", "Am Samstag gibt es hier Mittagessen.", False, "رۆژا شەمبیێ ل ڤێرێ خوارنا نیڤرۆ هەیە."),
  rf_t("📚 Stadtbibliothek\nBücher bitte hier zurückgeben – auch nachts möglich", "Man kann die Bücher auch in der Nacht zurückgeben.", True, "دشێی پەرتووکان ب شەڤ ژی بزڤڕینی."),
  rf_t("🚭 Rauchen nur im Hof erlaubt", "Man darf im Haus rauchen.", False, "دشێی ل ناڤ خانی جگارەیان بکێشی.")],
 form("Ihr Freund Metin Duski möchte Mitglied im Fitnessstudio werden. Sie füllen das Formular für ihn aus.\n\nMetin ist 31 Jahre alt und wohnt in der Bahnhofstraße 15 in 50667 Köln. Er möchte am Wochenende trainieren. Er bezahlt jeden Monat mit Karte.",
      "هەڤالێ تە دخوازیت ببیتە ئەندامێ یاریگەها وەرزشێ. فۆرمێ بۆ وی پڕ بکە.",
      [("Vorname", ["Metin"]), ("Alter", ["31", "31 Jahre", "einunddreißig"]), ("Wohnort", ["Köln", "50667 Köln"]),
       ("Trainingszeit (Woche / Wochenende)", ["Wochenende", "am Wochenende"]), ("Zahlung (bar / Karte)", ["Karte", "mit Karte"])]),
 write("Sie können morgen nicht zum Deutschkurs kommen. Schreiben Sie eine E-Mail an Ihre Lehrerin Frau Berger (ca. 30 Wörter).",
       "سوبەهی نەشێی بچیە خولا ئەلمانی. ئیمەیلەکێ بۆ مامۆستا خاتوو بێرگەر بنڤیسە (نێزیکی ٣٠ پەیڤان):",
       [("Warum schreiben Sie?", "بۆچی دنڤیسی؟", ["morgen", "nicht kommen", "kurs", "kann nicht"]),
        ("Warum können Sie nicht kommen?", "بۆچی نەشێی بێی؟", ["krank", "arzt", "arbeit", "termin", "weil", "kind"]),
        ("Fragen Sie nach den Hausaufgaben.", "پرسیارا ئەرکێن مالێ بکە.", ["hausaufgabe", "aufgaben", "schicken", "e-mail"])]),
 "Freizeit",
 [("Sport", "Welchen Sport machst du gern?"), ("Wochenende", "Was machst du am Wochenende?"), ("Kino", "Gehst du gern ins Kino?"), ("Musik", "Welche Musik hörst du gern?")],
 [("🚪", ["tür"], "Können Sie bitte die Tür zumachen?"), ("💧", ["wasser"], "Ein Glas Wasser, bitte."), ("🕐", ["uhr", "spät", "zeit"], "Wie spät ist es, bitte?"), ("📖", ["buch"], "Kannst du mir bitte das Buch geben?")]))

# ───────────────────────── Modelltest 3 ─────────────────────────
_m3a = "Liebe Avin,\nich bin jetzt in Hamburg. Das Wetter ist leider nicht so gut, es regnet jeden Tag. Aber die Stadt ist sehr schön! Gestern war ich im Hafen und im Museum. Am Freitag fahre ich nach Hause.\nBis bald\nPoya"
_m3b = "Sehr geehrte Damen und Herren,\nich möchte meine Reservierung im Hotel Sonne ändern. Ich komme nicht am 5. Mai, sondern am 6. Mai. Ich bleibe drei Nächte. Bitte schicken Sie mir eine Bestätigung.\nMit freundlichen Grüßen\nMohammed Nerweyi"
T.append(test(3,
 [mc(A("f: Wie kommst du morgen zur Arbeit? Mit dem Auto?", "m: Nein, mein Auto ist kaputt. Ich fahre mit dem Bus."), "Wie fährt der Mann zur Arbeit?", ["Mit dem Auto", "Mit dem Bus", "Mit dem Fahrrad"], 1, "زەلام ب چ دچیتە سەر کاری؟", ["🚗", "🚌", "🚲"]),
  mc(A("m: Wann beginnt der Film?", "f: Um acht. Aber wir treffen uns schon um halb acht vor dem Kino."), "Wann beginnt der Film?", ["19:30 Uhr", "20:00 Uhr", "20:30 Uhr"], 1, "فلم کەنگی دەست پێ دکەت؟"),
  mc(A("f: Was möchtest du trinken? Tee?", "m: Nein danke, keinen Tee. Ein Wasser, bitte."), "Was trinkt der Mann?", ["Tee", "Kaffee", "Wasser"], 2, "زەلام چ ڤەدخۆت؟", ["🍵", "☕", "💧"]),
  mc(A("m: Ich suche die Bäckerei. Ist sie hier rechts?", "f: Nein, gehen Sie links und dann geradeaus. Sie ist neben der Post."), "Wo ist die Bäckerei?", ["Rechts", "Neben der Post", "Neben der Bank"], 1, "نانەواخانە ل کیڤەیە؟"),
  mc(A("f: Haben Sie ein Zimmer frei? Für drei Nächte?", "m: Für drei Nächte leider nicht. Aber für zwei Nächte, ja."), "Für wie viele Nächte gibt es ein Zimmer?", ["Eine Nacht", "Zwei Nächte", "Drei Nächte"], 1, "ژوور بۆ چەند شەڤان هەیە؟"),
  mc(A("m: Hast du meine Brille gesehen? Liegt sie auf dem Tisch?", "f: Nein, sie ist im Bad, neben dem Spiegel."), "Wo ist die Brille?", ["Auf dem Tisch", "Im Bad", "Im Auto"], 1, "بەرچاڤک ل کیڤەیە؟")],
 [rf_a(A("f: Achtung: Das Schwimmbad schließt heute schon um achtzehn Uhr."), "Das Schwimmbad ist heute bis 20 Uhr offen.", False, "ئەڤرۆ مەلەڤانگەهـ هەتا دەمژمێر ٢٠ ڤەکرییە."),
  rf_a(A("m: Der ICE nach München fährt heute von Gleis vier."), "Der Zug nach München fährt von Gleis 4.", True, "شەمەندەفەرا میونشنێ ژ ڕێکا ٤ دچیت."),
  rf_a(A("f: Liebe Kunden, heute gibt es alle Getränke zum halben Preis."), "Die Getränke sind heute billiger.", True, "ئەڤرۆ ڤەخوارن ئەرزانترن."),
  rf_a(A("m: Information: Die U-Bahn Linie zwei fährt wegen Bauarbeiten bis Sonntag nicht."), "Die U-Bahn fährt am Wochenende normal.", False, "مترۆ دوماهیا هەفتێ ب ئاسایی دچیت.")],
 [mc(A("m: Hallo Huda, hier ist Zana. Ich habe zwei Karten für das Konzert am Samstag. Möchtest du mitkommen? Ruf mich an!"), "Was hat Zana?", ["Zwei Kinokarten", "Zwei Konzertkarten", "Zwei Fahrkarten"], 1, "زانا چ هەیە؟"),
  mc(A("f: Guten Tag, hier ist die Zahnarztpraxis Schulz. Bitte bringen Sie morgen Ihre Versichertenkarte mit."), "Was soll man mitbringen?", ["Geld", "Die Versichertenkarte", "Ein Foto"], 1, "دڤێت چ دگەل خۆ بینی؟"),
  mc(A("m: Hallo, ich bin's. Der Supermarkt ist schon zu. Ich kaufe die Milch morgen früh."), "Wann kauft er die Milch?", ["Heute Abend", "Morgen früh", "Morgen Abend"], 1, "ئەو کەنگی شیری دکڕیت؟"),
  mc(A("f: Hallo Herr Hamid, hier ist Frau Neumann. Unser Gespräch ist nicht am Dienstag, sondern am Mittwoch um zehn."), "Wann ist das Gespräch?", ["Dienstag, 10 Uhr", "Mittwoch, 10 Uhr", "Mittwoch, 12 Uhr"], 1, "دیدار کەنگی یە؟"),
  mc(A("m: Hi Dilin, hier ist Bnar. Ich kann heute nicht Fußball spielen, ich muss lernen. Vielleicht morgen?"), "Warum kann Bnar nicht kommen?", ["Er ist krank", "Er muss lernen", "Er muss arbeiten"], 1, "بۆچی بنار نەشێت بێت؟")],
 [rf_t(_m3a, "Poya ist in Hamburg.", True, "پۆیا ل هامبورگێ یە."),
  rf_t(_m3a, "In Hamburg scheint jeden Tag die Sonne.", False, "ل هامبورگێ هەر ڕۆژ هەتاڤە."),
  rf_t(_m3a, "Poya fährt am Freitag nach Hause.", True, "پۆیا ئەینیێ دزڤڕیتە مالێ."),
  rf_t(_m3b, "Herr Nerweyi kommt am 5. Mai.", False, "کاک نێروەیی رۆژا ٥ێ گولانێ دهێت."),
  rf_t(_m3b, "Er möchte eine Antwort vom Hotel.", True, "ئەو بەرسڤەکێ ژ ئوتێلێ دخوازیت.")],
 [ab("Sie möchten am Sonntag frühstücken gehen.", "Café Morgenrot – Frühstück täglich 8–12 Uhr", "Bistro Mitte – Mo–Fr ab 11 Uhr geöffnet", "a", "دخوازی یەکشەمبی بچی تێشتێ بخۆی."),
  ab("Sie möchten heute Abend zum Friseur, aber Sie haben keinen Termin.", "Salon Haarmonie – Di–Sa 9–20 Uhr, auch ohne Termin", "Friseur Klein – nur mit Termin, Mo–Fr 8–16 Uhr", "a", "ئەڤرۆ ئێڤاری دخوازی بچیە سەرتاشی، بەلێ ژڤانێ تە نینە."),
  ab("Sie möchten Ihre Kinder zum Schwimmkurs anmelden.", "Sportverein: Schwimmkurse für Kinder von 6 bis 10 Jahren", "Fitnessstudio: Schwimmen für Erwachsene ab 18", "a", "دخوازی زارۆکێن خۆ ل خولا مەلەڤانیێ تۆمار بکەی."),
  ab("Sie suchen eine Arbeit am Wochenende.", "Bäckerei sucht Verkäufer/in, Sa + So 6–12 Uhr", "Büro sucht Sekretär/in, Mo–Fr 8–16 Uhr", "a", "ل کارەکێ دوماهیا هەفتێ دگەڕێی."),
  ab("Sie möchten günstig nach Berlin fahren.", "Fernbus nach Berlin: ab 19 €", "Taxi Berlin: Flughafen-Service ab 45 €", "a", "دخوازی ب ئەرزانی بچیە بەرلینێ.")],
 [rf_t("🏥 Praxis Dr. Yilmaz\nSprechzeiten: Mo, Di, Do 8–12 Uhr\nMi + Fr geschlossen", "Am Mittwoch ist die Praxis geöffnet.", False, "رۆژا چوارشەمبیێ نۆڕینگەهـ ڤەکرییە."),
  rf_t("🐕 Hunde bitte draußen lassen", "Man darf mit dem Hund in das Geschäft gehen.", False, "دشێی دگەل سەی بچیە ناڤ دوکانێ."),
  rf_t("🅿️ Parkhaus\n1 Stunde: 2 €\nAb 18 Uhr: kostenlos", "Am Abend kostet Parken nichts.", True, "ئێڤاری ڕاگرتنا ترومبێلێ بێ پارەیە."),
  rf_t("🚲 Fahrräder bitte hier abstellen", "Hier kann man sein Fahrrad parken.", True, "دشێی پایسکلا خۆ ل ڤێرێ دانی."),
  rf_t("📦 Pakete bitte beim Nachbarn in Wohnung 3 abholen", "Man bekommt das Paket in Wohnung 3.", True, "پاکێتێ ل خانیێ ژمارە ٣ وەردگری.")],
 form("Ihre Schwester Huda Duski möchte ein Konto bei der Bank eröffnen. Sie füllen das Formular für sie aus.\n\nHuda ist 27 Jahre alt. Sie ist verheiratet und hat ein Kind. Sie arbeitet als Krankenschwester. Ihre Telefonnummer ist 0157 123456.",
      "خوشکا تە دخوازیت هەژمارەکێ ل بانکێ ڤەکەت. فۆرمێ بۆ وێ پڕ بکە.",
      [("Familienname", ["Duski"]), ("Alter", ["27", "27 Jahre", "siebenundzwanzig"]), ("Familienstand", ["verheiratet"]),
       ("Anzahl Kinder", ["1", "eins", "ein Kind"]), ("Beruf", ["Krankenschwester"])]),
 write("Sie sind neu in der Stadt und suchen eine Wohnung. Schreiben Sie eine E-Mail an Herrn Koch von der Wohnungsagentur (ca. 30 Wörter).",
       "تو نوو هاتییە باژێری و ل خانیەکی دگەڕێی. ئیمەیلەکێ بۆ کاک کۆخ بنڤیسە (نێزیکی ٣٠ پەیڤان):",
       [("Was suchen Sie?", "ل چ دگەڕێی؟", ["wohnung", "zimmer", "suche"]),
        ("Wie viel möchten Sie bezahlen?", "دخوازی چەند پارەی بدەی؟", ["euro", "€", "miete", "bezahlen", "kosten"]),
        ("Wann haben Sie Zeit für einen Termin?", "کەنگی دەمێ تە هەیە بۆ ژڤانەکی؟", ["termin", "zeit", "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "uhr"])]),
 "Einkaufen",
 [("Supermarkt", "Wo kaufst du ein?"), ("Kleidung", "Kaufst du gern Kleidung?"), ("Preis", "Was kostet ein Kilo Äpfel?"), ("Markt", "Gehst du gern auf den Markt?")],
 [("🧥", ["jacke"], "Kann ich die Jacke anprobieren?"), ("🔑", ["schlüssel"], "Kannst du mir bitte den Schlüssel geben?"), ("📱", ["handy", "telefon"], "Darf ich dein Handy benutzen?"), ("🍎", ["apfel", "äpfel"], "Ich möchte ein Kilo Äpfel, bitte.")]))

# ───────────────────────── Modelltest 4 ─────────────────────────
_m4a = "Hallo Metin,\nich habe eine neue Arbeit! Ich arbeite jetzt in einem Supermarkt in der Stadtmitte. Ich beginne jeden Tag um sieben Uhr und bin um fünfzehn Uhr fertig. Die Kollegen sind sehr nett. Am Sonntag habe ich frei.\nDein Safin"
_m4b = "Liebe Eltern,\nam Freitag, den 12. Juni, machen wir mit der Klasse einen Ausflug in den Zoo. Bitte geben Sie Ihrem Kind ein Frühstück und etwas zu trinken mit. Wir sind um 14 Uhr wieder in der Schule.\nFrau Weber"
T.append(test(4,
 [mc(A("f: Was möchtest du zum Geburtstag? Ein Buch?", "m: Ein Buch habe ich schon. Ich möchte gern eine Uhr."), "Was wünscht sich der Mann?", ["Ein Buch", "Eine Uhr", "Ein Handy"], 1, "زەلام چ دخوازیت؟", ["📖", "⌚", "📱"]),
  mc(A("m: Wann hast du Deutschkurs? Am Montag?", "f: Nein, am Dienstag und am Donnerstag."), "Wann hat die Frau Deutschkurs?", ["Montag und Mittwoch", "Dienstag und Donnerstag", "Montag und Freitag"], 1, "ئافرەت کەنگی خولا ئەلمانی هەیە؟"),
  mc(A("f: Ich möchte ein Brot und zwei Brötchen.", "m: Tut mir leid, Brot haben wir nicht mehr. Möchten Sie einen Kuchen?", "f: Nein, danke. Dann nur die Brötchen."), "Was kauft die Frau?", ["Brot", "Brötchen", "Kuchen"], 1, "ئافرەت چ دکڕیت؟", ["🍞", "🥖", "🍰"]),
  mc(A("m: Wie viel kostet die Fahrkarte nach Frankfurt?", "f: Normal kostet sie fünfzig Euro. Mit der Bahncard nur siebenunddreißig Euro fünfzig."), "Was kostet die Karte mit Bahncard?", ["37,50 €", "50 €", "57,50 €"], 0, "بلیت ب Bahncard ب چەندە؟"),
  mc(A("f: Wo ist die Katze? Im Garten?", "m: Nein, sie schläft auf dem Sofa."), "Wo ist die Katze?", ["Im Garten", "Auf dem Sofa", "Im Bett"], 1, "پشیک ل کیڤەیە؟", ["🌳", "🛋️", "🛏️"]),
  mc(A("m: Entschuldigung, wann fährt der letzte Bus?", "f: Um dreiundzwanzig Uhr zehn. Aber am Wochenende fährt er bis Mitternacht."), "Wann fährt der letzte Bus unter der Woche?", ["22:10 Uhr", "23:10 Uhr", "24:00 Uhr"], 1, "پاسا دوماهیێ ل ڕۆژێن کاری کەنگی دچیت؟")],
 [rf_a(A("m: Achtung: Der Zug nach Frankfurt hat zehn Minuten Verspätung."), "Der Zug kommt zu spät.", True, "شەمەندەفەر درەنگ دهێت."),
  rf_a(A("f: Liebe Besucher, das Museum ist am Montag geschlossen."), "Man kann das Museum am Montag besuchen.", False, "دشێی رۆژا دووشەمبیێ سەرەدانا مۆزەخانێ بکەی."),
  rf_a(A("m: Sehr geehrte Kunden, an Kasse drei können Sie nur mit Karte bezahlen."), "An Kasse 3 kann man bar bezahlen.", False, "ل سندووقا ٣ دشێی ب نەقدی پارەی بدەی."),
  rf_a(A("f: Information für alle Kursteilnehmer: Der Deutschkurs beginnt heute eine Stunde später, um zehn Uhr."), "Der Kurs beginnt heute um zehn Uhr.", True, "ئەڤرۆ خول دەمژمێر ١٠ دەست پێ دکەت.")],
 [mc(A("f: Hallo Samad, hier ist Lina. Ich bin krank und kann heute nicht arbeiten. Kannst du für mich kommen?"), "Was möchte Lina?", ["Samad soll für sie arbeiten", "Samad soll zum Arzt gehen", "Samad soll sie besuchen"], 0, "لینا چ دخوازیت؟"),
  mc(A("m: Guten Tag, hier ist das Reisebüro Sonnenschein. Ihre Tickets nach Antalya sind da. Sie können sie ab Montag abholen."), "Ab wann kann man die Tickets abholen?", ["Ab Sonntag", "Ab Montag", "Ab Mittwoch"], 1, "ژ کەنگی ڤە دشێی بلیتان وەربگری؟"),
  mc(A("f: Hallo Poya, ich bin's, Avin. Kannst du bitte die Medikamente aus der Apotheke holen? Die Apotheke schließt um sechs."), "Was soll Poya holen?", ["Brot", "Medikamente", "Blumen"], 1, "دڤێت پۆیا چ بینیت؟"),
  mc(A("m: Hallo, hier ist Hausmeister Becker. Morgen von acht bis zwölf Uhr gibt es kein Wasser im Haus."), "Wann gibt es kein Wasser?", ["Heute Abend", "Morgen Vormittag", "Morgen Nachmittag"], 1, "کەنگی ئاڤ نابیت؟"),
  mc(A("f: Hi Safin, hier ist Dilhin. Das Fußballspiel ist nicht am Samstag, sondern am Sonntag um drei."), "Wann ist das Fußballspiel?", ["Samstag, 15 Uhr", "Sonntag, 13 Uhr", "Sonntag, 15 Uhr"], 2, "یاریا تۆپێ کەنگی یە؟")],
 [rf_t(_m4a, "Safin arbeitet in einem Supermarkt.", True, "سەفین ل سوپەرمارکێتەکێ کار دکەت."),
  rf_t(_m4a, "Safin arbeitet bis 17 Uhr.", False, "سەفین هەتا دەمژمێر ١٧ کار دکەت."),
  rf_t(_m4a, "Am Sonntag muss Safin arbeiten.", False, "یەکشەمبی دڤێت سەفین کار بکەت."),
  rf_t(_m4b, "Die Kinder brauchen etwas zu essen und zu trinken.", True, "زارۆک پێدڤی ب خوارن و ڤەخوارنێ نە."),
  rf_t(_m4b, "Die Kinder kommen um 16 Uhr zurück.", False, "زارۆک دەمژمێر ١٦ دزڤڕن.")],
 [ab("Sie möchten am Abend Deutsch lernen.", "Deutschkurs A1 – Mo + Do 18:30–20:30 Uhr", "Deutschkurs A1 – Di + Fr 9–12 Uhr", "a", "دخوازی ئێڤاری ئەلمانی فێر ببی."),
  ab("Ihr Handy ist kaputt.", "Handy-Doktor: Reparatur in einer Stunde", "Handy-Shop: neue Verträge und Tarife", "a", "مۆبایلا تە خەراب بوویە."),
  ab("Sie möchten mit Ihrer Familie am Sonntag in den Park.", "Stadtpark: Spielplatz und Café, täglich geöffnet", "Botanischer Garten: Mo–Fr 9–16 Uhr", "a", "دخوازی یەکشەمبی دگەل خێزانێ بچیە پارکێ."),
  ab("Sie brauchen Möbel für wenig Geld.", "Möbelhaus Luxus – neue Designermöbel", "Sozialkaufhaus – gebrauchte Möbel, sehr günstig", "b", "پێدڤی ب کەلوپەلێن مالێ یێن ئەرزان هەیە."),
  ab("Sie wollen am Samstag zum Arzt.", "Praxis Dr. Klein – Samstag 9–12 Uhr Sprechstunde", "Praxis Dr. Weiß – Mo–Fr 8–17 Uhr", "a", "دخوازی شەمبی بچیە نک دکتۆری.")],
 [rf_t("🛒 Supermarkt\nNeue Öffnungszeiten ab 1. April:\nMo–Sa 7–22 Uhr", "Der Supermarkt ist am Sonntag geöffnet.", False, "سوپەرمارکێت یەکشەمبی ڤەکرییە."),
  rf_t("🎟️ Kinder unter 6 Jahren: Eintritt frei", "Ein Kind mit 4 Jahren muss nicht bezahlen.", True, "زارۆکەکێ ٤ ساڵی پێدڤی نینە پارەی بدەت."),
  rf_t("📵 Bitte keine Handys im Wartezimmer", "Man darf im Wartezimmer telefonieren.", False, "دشێی ل ژوورا چاڤەڕێکرنێ تەلەفۆنێ بکەی."),
  rf_t("🧺 Waschraum im Keller\nWaschmaschinen täglich 7–21 Uhr", "Man kann um 20 Uhr Wäsche waschen.", True, "دشێی دەمژمێر ٢٠ جلکان بشۆی."),
  rf_t("🚌 Ersatzverkehr\nBitte nehmen Sie den Bus vor dem Bahnhof", "Man fährt hier heute mit dem Zug.", False, "ئەڤرۆ ل ڤێرێ ب شەمەندەفەرێ دچی.")],
 form("Ihr Kollege Hamid Koçer möchte einen Ausweis für die Bibliothek. Sie füllen das Formular für ihn aus.\n\nHamid ist am 3. Mai 1990 geboren. Er wohnt in der Lindenstraße 21 in 10115 Berlin. Er möchte Bücher und Filme ausleihen. Seine E-Mail ist hamid.k@mail.de.",
      "هەڤالێ تە یێ کاری دخوازیت کارتا پەرتووکخانێ وەربگریت. فۆرمێ بۆ وی پڕ بکە.",
      [("Vorname", ["Hamid"]), ("Geburtsdatum", ["3. Mai 1990", "03.05.1990", "3.5.1990"]), ("Straße, Hausnummer", ["Lindenstraße 21"]),
       ("Ausleihen (Bücher / Filme / beides)", ["beides", "Bücher und Filme"]), ("E-Mail", ["hamid.k@mail.de"])]),
 write("Ihre Freundin Dilin hat ein Baby bekommen. Schreiben Sie ihr eine Karte (ca. 30 Wörter).",
       "هەڤالا تە دیلین بوویە دایک. کارتەکێ بۆ وێ بنڤیسە (نێزیکی ٣٠ پەیڤان):",
       [("Gratulieren Sie.", "پیرۆزباهیێ لێ بکە.", ["gratuliere", "glückwunsch", "herzlich"]),
        ("Fragen Sie: Wie heißt das Baby?", "بپرسە: ناڤێ زارۆکی چیە؟", ["heißt", "name"]),
        ("Wann können Sie Dilin besuchen?", "کەنگی دشێی سەرەدانا دیلینێ بکەی؟", ["besuchen", "komme", "zeit", "samstag", "sonntag", "woche"])]),
 "Wohnen",
 [("Zimmer", "Wie viele Zimmer hat deine Wohnung?"), ("Miete", "Wie hoch ist deine Miete?"), ("Nachbarn", "Hast du nette Nachbarn?"), ("Küche", "Ist deine Küche groß?")],
 [("🍰", ["kuchen"], "Darf ich ein Stück Kuchen haben?"), ("☂️", ["regenschirm", "schirm"], "Kannst du mir deinen Regenschirm leihen?"), ("🧾", ["rechnung"], "Die Rechnung, bitte."), ("🎵", ["musik", "leiser"], "Mach bitte die Musik leiser.")]))

# ───────────────────────── Modelltest 5 ─────────────────────────
_m5a = "Hallo Zana,\nwie geht es dir? Ich bin jetzt seit zwei Wochen in Wien. Ich mache hier einen Deutschkurs. Der Kurs ist jeden Tag von neun bis dreizehn Uhr. Nachmittags arbeite ich in einem Café. Wien ist sehr schön, aber teuer!\nViele Grüße\nHamid"
_m5b = "Liebe Nachbarn,\nam Samstag feiern wir ein Hoffest! Es gibt Musik, Grillen und Kuchen. Wir beginnen um 15 Uhr. Bitte bringen Sie einen Salat oder Getränke mit.\nFamilie Koçer, 2. Stock"
T.append(test(5,
 [mc(A("m: Was isst du heute Mittag? Pizza?", "f: Nein, ich esse Suppe. Pizza hatte ich gestern."), "Was isst die Frau heute?", ["Pizza", "Suppe", "Salat"], 1, "ئافرەت ئەڤرۆ چ دخۆت؟", ["🍕", "🍲", "🥗"]),
  mc(A("f: Wie alt ist dein Sohn? Schon zehn?", "m: Nein, er ist acht. Seine Schwester ist zehn."), "Wie alt ist der Sohn?", ["8 Jahre", "10 Jahre", "12 Jahre"], 0, "کوڕ چەند ساڵە؟"),
  mc(A("m: Wohin fährst du im Urlaub? Ans Meer?", "f: Dieses Jahr nicht. Ich fahre in die Berge."), "Wohin fährt die Frau?", ["Ans Meer", "In die Berge", "In die Stadt"], 1, "ئافرەت بۆ کیڤە دچیت؟", ["🏖️", "🏔️", "🏙️"]),
  mc(A("f: Was kosten die Schuhe?", "m: Die schwarzen kosten sechzig Euro, die braunen fünfundvierzig.", "f: Dann nehme ich die braunen."), "Wie viel bezahlt die Frau?", ["45 €", "60 €", "65 €"], 0, "ئافرەت چەند پارەی ددەت؟"),
  mc(A("m: Wie ist das Wetter heute in Berlin?", "f: Es ist kalt, aber die Sonne scheint."), "Wie ist das Wetter?", ["Regen", "Sonne", "Schnee"], 1, "کەشوهەوا چاوا یە؟", ["🌧️", "☀️", "❄️"]),
  mc(A("m: Wann hast du Zeit? Am Vormittag?", "f: Vormittags arbeite ich. Aber ab drei Uhr bin ich frei."), "Ab wann hat die Frau Zeit?", ["Ab 13 Uhr", "Ab 15 Uhr", "Ab 17 Uhr"], 1, "ئافرەت ژ کەنگی ڤە دەمێ وێ هەیە؟")],
 [rf_a(A("m: Liebe Fahrgäste, wegen eines Unfalls fährt die Straßenbahn heute nur bis zum Rathaus."), "Die Straßenbahn fährt heute nicht bis zum Ende.", True, "ئەڤرۆ ترامڤای هەتا دوماهیێ ناچیت."),
  rf_a(A("f: Achtung: Der Parkplatz vor dem Krankenhaus ist heute gesperrt."), "Man kann heute vor dem Krankenhaus parken.", False, "ئەڤرۆ دشێی ل بەر نەخۆشخانێ ترومبێلێ ڕاگری."),
  rf_a(A("m: Information: Die Bibliothek hat ab nächster Woche auch samstags geöffnet."), "Ab nächster Woche ist die Bibliothek am Samstag offen.", True, "ژ هەفتا بێت ڤە پەرتووکخانە شەمبیان ڤەکرییە."),
  rf_a(A("f: Liebe Gäste, das Frühstück gibt es heute im Garten, nicht im Restaurant."), "Das Frühstück ist heute im Restaurant.", False, "ئەڤرۆ تێشت ل خوارنگەهێ یە.")],
 [mc(A("m: Hallo Bnar, hier ist Papa. Ich hole dich heute nicht um vier, sondern um fünf von der Schule ab."), "Wann holt der Vater Bnar ab?", ["Um 4 Uhr", "Um 5 Uhr", "Um 6 Uhr"], 1, "باب کەنگی بنار ژ قوتابخانێ دبەت؟"),
  mc(A("f: Guten Tag, hier ist die Stadtbibliothek. Ihr Buch ist da. Sie können es bis Freitag abholen."), "Bis wann kann man das Buch abholen?", ["Bis Mittwoch", "Bis Donnerstag", "Bis Freitag"], 2, "هەتا کەنگی دشێی پەرتووکێ وەربگری؟"),
  mc(A("m: Hallo Huda, hier ist Metin. Ich habe meinen Schlüssel vergessen. Bist du zu Hause? Ich komme in zwanzig Minuten."), "Was hat Metin vergessen?", ["Sein Handy", "Seinen Schlüssel", "Seine Tasche"], 1, "مەتین چ ژبیر کریە؟"),
  mc(A("f: Hallo, hier ist Frau Berger, Ihre Nachbarin. Ein Paket für Sie ist bei mir. Ich bin bis acht Uhr zu Hause."), "Wo ist das Paket?", ["Bei der Post", "Bei der Nachbarin", "Im Briefkasten"], 1, "پاکێت ل کیڤەیە؟"),
  mc(A("m: Guten Tag, hier ist die Fahrschule Schnell. Ihre Fahrstunde ist morgen nicht um neun, sondern um elf."), "Wann ist die Fahrstunde?", ["Morgen, 9 Uhr", "Morgen, 11 Uhr", "Übermorgen, 11 Uhr"], 1, "وانەیا شۆفێریێ کەنگی یە؟")],
 [rf_t(_m5a, "Hamid ist seit zwei Wochen in Wien.", True, "حەمید دوو هەفتێن ل ڤیەنا."),
  rf_t(_m5a, "Hamid arbeitet am Vormittag.", False, "حەمید بەری نیڤرۆ کار دکەت."),
  rf_t(_m5a, "Wien ist billig.", False, "ڤیەنا ئەرزانە."),
  rf_t(_m5b, "Das Fest beginnt am Samstagnachmittag.", True, "ئاهەنگ شەمبی پشتی نیڤرۆ دەست پێ دکەت."),
  rf_t(_m5b, "Die Nachbarn sollen Fleisch mitbringen.", False, "دڤێت جیران گۆشتی دگەل خۆ بینن.")],
 [ab("Sie möchten Ihr Auto waschen.", "Autowaschanlage – Mo–Sa 7–20 Uhr", "Autohaus Kraft – neue und gebrauchte Autos", "a", "دخوازی ترومبێلا خۆ بشۆی."),
  ab("Sie suchen einen Babysitter für Samstagabend.", "Studentin (22) passt abends und am Wochenende auf Kinder auf", "Kita Sonnenschein – Mo–Fr 7–17 Uhr", "a", "ل کەسەکی دگەڕێی کو شەمبی ئێڤاری زارۆکێن تە بپارێزیت."),
  ab("Sie möchten einen Computerkurs für Anfänger machen.", "Kurs „Computer für Profis“ – Programmieren", "Volkshochschule: Computer – erste Schritte", "b", "دخوازی خولا کۆمپیوتەرێ بۆ دەستپێکەران بکەی."),
  ab("Sie möchten Ihre Wohnung streichen und brauchen Hilfe.", "Malerbetrieb Farbe – wir streichen schnell und günstig", "Kunstschule – Malkurse für Kinder", "a", "دخوازی خانیێ خۆ ڕەنگ بکەی و پێدڤی ب هاریکاریێ هەیە."),
  ab("Sie möchten heute Abend ein Fußballspiel sehen.", "Sportbar Anstoß – alle Spiele live auf großer Leinwand", "Sportgeschäft – Fußballschuhe 20 % billiger", "a", "دخوازی ئەڤرۆ ئێڤاری یاریەکا تۆپێ ببینی.")],
 [rf_t("🏫 Sekretariat\nHeute nur bis 11 Uhr geöffnet", "Das Sekretariat ist heute am Nachmittag offen.", False, "ئەڤرۆ پشتی نیڤرۆ سکرتاریەت ڤەکرییە."),
  rf_t("🔇 Bitte leise! Prüfung", "Man soll hier ruhig sein.", True, "دڤێت ل ڤێرێ بێدەنگ بی."),
  rf_t("🥤 Getränke-Automat\nNur Münzen, keine Scheine", "Man kann hier mit einem 10-Euro-Schein bezahlen.", False, "دشێی ل ڤێرێ ب کاغەزەکا ١٠ یۆرۆیی پارەی بدەی."),
  rf_t("👕 Sommerschlussverkauf\nAlle T-Shirts –50 %", "Die T-Shirts kosten nur die Hälfte.", True, "تیشێرت ب نیڤا بهای نە."),
  rf_t("🚪 Notausgang – nicht abschließen!", "Diese Tür muss man immer abschließen.", False, "دڤێت ئەڤ دەرگەهە هەردەم ب کلیلێ بهێتە گرتن.")],
 form("Ihr Freund Zana Nerweyi möchte in einem Fußballverein spielen. Sie füllen das Formular für ihn aus.\n\nZana ist 19 Jahre alt und Student. Er wohnt in der Schulstraße 4 in 80331 München. Er kann am Dienstag und am Donnerstag trainieren. Seine Handynummer ist 0172 998877.",
      "هەڤالێ تە دخوازیت ل یانەیەکا تۆپا پێ یاری بکەت. فۆرمێ بۆ وی پڕ بکە.",
      [("Familienname", ["Nerweyi"]), ("Alter", ["19", "19 Jahre", "neunzehn"]), ("Beruf", ["Student"]),
       ("Wohnort", ["München", "80331 München"]), ("Trainingstage", ["Dienstag und Donnerstag", "Di und Do", "Di + Do", "Dienstag, Donnerstag"])]),
 write("Sie möchten am Wochenende mit Ihrer Freundin Lina ins Kino gehen. Schreiben Sie ihr eine Nachricht (ca. 30 Wörter).",
       "دخوازی دوماهیا هەفتێ دگەل هەڤالا خۆ لینا بچیە سینەمایێ. نامەیەکێ بۆ وێ بنڤیسە (نێزیکی ٣٠ پەیڤان):",
       [("Laden Sie Lina ein.", "لینایێ داخواز بکە (بانگهێشت بکە).", ["kino", "kommst du", "einladen", "möchtest du", "lust"]),
        ("Wann und wo treffen Sie sich?", "کەنگی و ل کیڤە ئێکدو دبینن؟", ["uhr", "samstag", "sonntag", "treffen", "vor dem"]),
        ("Was machen Sie nach dem Film?", "پشتی فلمی دێ چ کەن؟", ["essen", "café", "pizza", "danach", "nach dem film", "restaurant"])]),
 "Arbeit und Beruf",
 [("Beruf", "Was bist du von Beruf?"), ("Arbeitszeit", "Wann beginnt deine Arbeit?"), ("Kollegen", "Hast du nette Kollegen?"), ("Urlaub", "Wie viel Urlaub hast du?")],
 [("🚕", ["taxi"], "Können Sie mir bitte ein Taxi rufen?"), ("📸", ["foto"], "Können Sie bitte ein Foto von uns machen?"), ("🔊", ["lauter", "laut"], "Können Sie bitte lauter sprechen?"), ("✏️", ["bleistift", "stift"], "Kannst du mir bitte einen Bleistift geben?")]))

# ✅ پشکنین: هەر تاقیکرنەک ١٥ + ١٥ پرسیار
for t in T:
    h = sum(len(s["items"]) for s in t["parts"][0]["sections"]); l = sum(len(s["items"]) for s in t["parts"][1]["sections"])
    assert h == 15 and l == 15, (t["id"], h, l)
    for s in t["parts"][0]["sections"] + t["parts"][1]["sections"]:
        for it in s["items"]:
            if it["t"] == "mc":
                assert 0 <= it["answer"] < len(it["options"]) and (not it.get("pics") or len(it["pics"]) == len(it["options"]))
d["tests"] = T
P.write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print("tests:", [t["id"] for t in T])
