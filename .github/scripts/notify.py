"""
📬 ASP notifications — هەر ١٥ خولەکان ل GitHub Actions:
  ١. نامەیێن ئەدمینی (pushed_at = null) ➔ Web Push بۆ فێرخواز(ان)
  ٢. بیرئینانا Streak: ئێڤاری (≥ 18:00 ل دهۆکێ)، ئەگەر ئەڤرۆ نەخواندبیت ➔ نامە + Push
پێدڤی: SUPABASE_URL و SUPABASE_SERVICE_KEY وەکی GitHub Secrets.
"""
import json, os, sys
from datetime import datetime, timedelta, timezone

import requests
from pywebpush import WebPushException, webpush

URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
if not URL or not KEY:
    print("SUPABASE_URL / SUPABASE_SERVICE_KEY not set — skipping"); sys.exit(0)
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


secret = get("app_secrets?key=eq.vapid_private&select=value")
VAPID = secret[0]["value"] if secret else None
learners = {l["id"]: l for l in get("learners?select=id,name,push_sub,streak,last_study_date,streak_reminded_on")}


def push(learner, title, body):
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
for m in get("messages?pushed_at=is.null&select=*&order=created_at.asc&limit=100"):
    targets = [learners[m["learner_id"]]] if m.get("learner_id") in learners else (list(learners.values()) if m.get("learner_id") is None else [])
    for l in targets:
        sent += push(l, m["title"], m["body"])
    patch(f"messages?id=eq.{m['id']}", {"pushed_at": datetime.now(timezone.utc).isoformat()})
print("messages pushed:", sent)

# ٢. بیرئینانا Streak
reminded = 0
if now.hour >= 18:
    for l in learners.values():
        if (l.get("streak") or 0) < 1 or l.get("last_study_date") == today or l.get("streak_reminded_on") == today:
            continue
        name = l.get("name") or ""
        title = f"🔥 {name}، Streak ـا تە دێ چیت!"
        body = f"تە {l['streak']} رۆژ ل دویف ئێک خواندییە. دەمەکێ کێم ماوە — وانەیەکا ٥ خولەکان بکە دا Streak ـا تە نەچیت!"
        post("messages", {"learner_id": l["id"], "title": title, "body": body, "kind": "streak",
                          "pushed_at": datetime.now(timezone.utc).isoformat()})
        push(l, title, body)
        patch(f"learners?id=eq.{l['id']}", {"streak_reminded_on": today})
        reminded += 1
print("streak reminders:", reminded)
