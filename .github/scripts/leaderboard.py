"""🏆 لیستا باشترینان یا هەفتیێ: XP ژ رۆژا دووشەمبیێ ڤە (دەمێ بەغدا) ➔ content.leaderboard (هەمی کەس دشێن بخوینن).
تنێ ناڤێ ئێکێ و XP دهێنە نیشاندان — نە ئیمەیل، نە باژێڕ."""
import os, datetime, requests
URL = "https://pecnuohpxraoxvfjsngm.supabase.co"
S = os.environ["SUPABASE_SERVICE_KEY"].strip()
H = {"apikey": S, "Authorization": f"Bearer {S}", "Content-Type": "application/json"}
now = datetime.datetime.utcnow() + datetime.timedelta(hours=3)  # Asia/Baghdad
monday = (now - datetime.timedelta(days=now.weekday())).date().isoformat()
act = requests.get(f"{URL}/rest/v1/activity?day=gte.{monday}&select=learner_id,xp", headers=H, timeout=30).json()
tot = {}
for a in act:
    tot[a["learner_id"]] = tot.get(a["learner_id"], 0) + (a.get("xp") or 0)
names = {r["id"]: r.get("name") or "" for r in requests.get(f"{URL}/rest/v1/learners?select=id,name", headers=H, timeout=30).json()}
rows = []
for lid, xp in sorted(tot.items(), key=lambda kv: -kv[1]):
    n = (names.get(lid) or "").strip()
    if xp <= 0 or not n or n == "SMOKE TEST":
        continue
    rows.append({"k": lid[:8], "name": n.split()[0][:14], "xp": xp})
    if len(rows) >= 30:
        break
body = {"key": "leaderboard", "value": {"week": monday, "updated": now.strftime("%Y-%m-%d %H:%M"), "rows": rows},
        "updated_at": datetime.datetime.utcnow().isoformat() + "Z"}
r = requests.post(f"{URL}/rest/v1/content", headers={**H, "Prefer": "resolution=merge-duplicates"}, json=body, timeout=30)
print("leaderboard", r.status_code, len(rows), "rows, week", monday)
r.raise_for_status()
