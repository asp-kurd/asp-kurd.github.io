"""
📬 ASP notifications — هەر ١٥ خولەکان ل GitHub Actions:
  ١. نامەیێن ئەدمینی (pushed_at = null) ➔ Web Push بۆ فێرخواز(ان)
  ٢. بیرئینانا Streak: ئێڤاری (≥ 18:00 ل دهۆکێ)، ئەگەر ئەڤرۆ نەخواندبیت ➔ نامە + Push
پێدڤی: SUPABASE_URL و SUPABASE_SERVICE_KEY وەکی GitHub Secrets.
"""
import json, os, re, sys
from datetime import datetime, timedelta, timezone

import requests
from pywebpush import WebPushException, webpush

_u = os.environ.get("SUPABASE_URL", "").strip()
_k = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()
if _k.startswith("http") and not _u.startswith("http"):  # ئەگەر هەردوو تێکەلی ئێک بووبن
    os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_KEY"] = _k, _u
    print("::notice title=notify::URL and key were swapped — fixed automatically")
URL = (os.environ.get("SUPABASE_URL") or "https://pecnuohpxraoxvfjsngm.supabase.co").strip().rstrip("/")
if not URL.startswith("http"):
    URL = "https://pecnuohpxraoxvfjsngm.supabase.co"
KEY = os.environ.get("SUPABASE_SERVICE_KEY", "").strip().strip('"').strip("'")
# iPhone هندەک جاران پیتا ئێکێ مەزن دکەت (Sb_secret_…)
for pre in ("sb_secret_", "sb_publishable_"):
    if KEY.lower().startswith(pre):
        KEY = pre + KEY[len(pre):]
if not URL or not KEY:
    print("::warning title=notify::SUPABASE_URL / SUPABASE_SERVICE_KEY not set — skipping"); sys.exit(0)
H = {"apikey": KEY, "Content-Type": "application/json"}
if KEY.startswith("eyJ"):  # کلیلا کەڤن (JWT)
    H["Authorization"] = f"Bearer {KEY}"
TZ = timezone(timedelta(hours=3))  # Asia/Baghdad
now = datetime.now(TZ)
today = now.date().isoformat()


def get(path):
    r = requests.get(f"{URL}/rest/v1/{path}", headers=H, timeout=30); r.raise_for_status(); return r.json()


def patch(path, body):
    requests.patch(f"{URL}/rest/v1/{path}", headers=H, data=json.dumps(body), timeout=30).raise_for_status()


def post(path, body):
    r = requests.post(f"{URL}/rest/v1/{path}", headers={**H, "Prefer": "return=representation"}, data=json.dumps(body), timeout=30)
    r.raise_for_status(); return r.json()


kind = "secret" if KEY.startswith("sb_secret_") else "publishable(WRONG)" if KEY.startswith("sb_publishable_") else "legacy-jwt" if KEY.startswith("eyJ") else f"unknown(len={len(KEY)}, starts={KEY[:3]!r})"
print(f"::notice title=notify::key_type={kind}")
secret = get("app_secrets?key=eq.vapid_private&select=value")
VAPID = secret[0]["value"] if secret else None
learners = {l["id"]: l for l in get("learners?select=id,name,push_sub,streak,last_study_date,streak_reminded_on")}


def push(learner, title, body):
    # کارێن ئەدمینی (⟦asp:{…}⟧) د ئاگەهداریێ دا نائێنە نیشاندان
    body = re.sub(r"⟦asp:.*?⟧", "", body or "", flags=re.S).strip() or "🎁 ASP"
    sub = learner.get("push_sub")
    if not sub or not VAPID:
        return False
    try:
        webpush(subscription_info=sub, data=json.dumps({"title": title, "body": body}),
                vapid_private_key=VAPID, vapid_claims={"sub": "mailto:groupkurdish@gmail.com"}, ttl=86400)
        return True
    except WebPushException as e:
        code = getattr(e.response, "status_code", None)
        print("push failed", learner["name"], code)
        if code in (404, 410):  # subscription expired
            patch(f"learners?id=eq.{learner['id']}", {"push_sub": None})
        return False


# ١. نامەیێن نوو
sent = 0
# 💬 نامێن فێرخوازان بۆ ئەدمینی ➔ ئاگەهداری بۆ هەژمارێن ئەدمینی (ئەگەر ل سەر مۆبایلێ ئاگەهداری ڤەکربن)
try:
    admin_emails = {a["email"].lower() for a in get("admins?select=email")}
    admin_rows = [l for l in get("learners?select=id,name,email,push_sub") if (l.get("email") or "").lower() in admin_emails]
except Exception as e:  # ستوونا email نینە
    admin_rows = []
for m in get("messages?pushed_at=is.null&select=*&order=created_at.asc&limit=100"):
    if m.get("from_learner"):
        who = learners.get(m.get("learner_id"), {}).get("name", "")
        targets = admin_rows
        m = {**m, "title": f"💬 {who}", "body": m.get("body", "")}
    elif m.get("kind") == "chat":
        targets = [learners[m["learner_id"]]] if m.get("learner_id") in learners else []
        m = {**m, "title": "💬 بەرسڤا ئەدمینێ ASP"}
    else:
        targets = [learners[m["learner_id"]]] if m.get("learner_id") in learners else (list(learners.values()) if m.get("learner_id") is None else [])
    for l in targets:
        sent += push(l, m["title"], m["body"])
    patch(f"messages?id=eq.{m['id']}", {"pushed_at": datetime.now(timezone.utc).isoformat()})
print(f"::notice title=notify::learners={len(learners)} with_push={sum(1 for l in learners.values() if l.get('push_sub'))} vapid={'yes' if VAPID else 'no'} messages_pushed={sent}")

# ٢. بیرئینانا Streak: ٣–٤ جاران بەری نیڤا شەڤێ (18:00 · 20:00 · 22:00 · 23:15)، هەر جار ب شێوەکێ جودا
SLOTS = [(18, 0), (20, 0), (22, 0), (23, 15)]
due_slots = sum(1 for h, m in SLOTS if (now.hour, now.minute) >= (h, m))
reminded = 0
if due_slots:
    start = datetime(now.year, now.month, now.day, tzinfo=TZ).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")  # بێ «+» (د URL دا دبیتە بۆشایی)
    sent_today = {}
    for m in get(f"messages?kind=eq.streak&created_at=gte.{start}&select=learner_id"):
        sent_today[m["learner_id"]] = sent_today.get(m["learner_id"], 0) + 1
    risk = [l for l in learners.values()
            if (l.get("streak") or 0) >= 1 and l.get("last_study_date") != today and l.get("push_sub")
            and sent_today.get(l["id"], 0) < due_slots]
    freezes = {}
    if risk:
        ids = ",".join(l["id"] for l in risk)
        try:
            for r in get(f"progress?user_id=in.({ids})&select=user_id,fz:data->>freezes"):
                freezes[r["user_id"]] = int(r.get("fz") or 0)
        except Exception as e:
            print("freezes lookup failed", e)
    for l in risk:
        k = sent_today.get(l["id"], 0)  # ئەڤە جارا چەندێ یە (0..3)
        name = l.get("name") or ""
        st = l["streak"]
        fz = freezes.get(l["id"], 0)
        msgs = [
            (f"🔥 {name}، ئاگرێ تە چاڤەڕێیا تە یە!", f"تە {st} رۆژ ل دویف ئێک خواندییە. وانەیەکا ٥ خولەکان بەسە دا ئاگر نەڤەمریت."),
            (f"⏰ {name}، دەم دچیت…", f"هێشتا ئەڤرۆ تە نەخواندییە! Streak ـا {st} رۆژان یا تەیە — ٥ خولەکان بدە ئێک وانێ 💪"),
            (f"😟 {name}، ئاگرێ تە بچووک دبیت!", f"تنێ دوو دەمژمێر ماینە بۆ نیڤا شەڤێ. {st} 🔥 نەهێلە بچیت!"
             + (" (قەشا تە هەیە 🧊، بەلێ بۆچی وێ بکار بینی؟)" if fz else "")),
            (f"🚨 {name}، دویماهیک دەرفەت!", f"ل دەمژمێر ١٢ێ شەڤێ Streak ـا {st} رۆژان دێ ڤەمریت"
             + (" — یان قەشا تە دێ هێتە بکارئینان 🧊." if fz else "!") + " ئێک وانەیا کورت نوکە 🙏"),
        ]
        title, body = msgs[min(k, len(msgs) - 1)]
        if push(l, title, body):
            post("messages", {"learner_id": l["id"], "title": title, "body": body, "kind": "streak",
                              "pushed_at": datetime.now(timezone.utc).isoformat(),
                              "read_at": datetime.now(timezone.utc).isoformat()})
            patch(f"learners?id=eq.{l['id']}", {"streak_reminded_on": today})
            reminded += 1
print(f"::notice title=notify::streak_reminders={reminded} hour={now.hour} slots={due_slots}")
