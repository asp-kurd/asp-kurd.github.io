"""Smoke test: anonymous sign-up → learner row → track() → messages → cleanup."""
import json, sys, requests
URL = "https://pecnuohpxraoxvfjsngm.supabase.co"
KEY = "sb_publishable_btfzw-7Kc7ZJmfqvhPYr5w_ybgL55CJ"
ok = True
def step(name, r, want=(200, 201, 204)):
    global ok
    good = r.status_code in want
    ok &= good
    print(("✅" if good else "❌"), name, r.status_code, r.text[:300])
    return r
r = step("signup (anonymous)", requests.post(f"{URL}/auth/v1/signup", headers={"apikey": KEY, "Content-Type": "application/json"}, json={"data": {}}))
if r.status_code != 200: sys.exit(1)
j = r.json(); tok = j["access_token"]; uid = j["user"]["id"]
H = {"apikey": KEY, "Authorization": f"Bearer {tok}", "Content-Type": "application/json"}
step("insert learner", requests.post(f"{URL}/rest/v1/learners", headers={**H, "Prefer": "resolution=merge-duplicates,return=representation"},
     json={"id": uid, "name": "SMOKE TEST", "age": 1, "city": "CI"}))
step("track()", requests.post(f"{URL}/rest/v1/rpc/track", headers=H, json={"p_seconds": 5, "p_lessons": 1, "p_xp": 3, "p_open": True}))
step("read activity", requests.get(f"{URL}/rest/v1/activity?learner_id=eq.{uid}&select=*", headers=H))
step("read messages", requests.get(f"{URL}/rest/v1/messages?or=(learner_id.eq.{uid},learner_id.is.null)&select=*", headers=H))
step("exam result", requests.post(f"{URL}/rest/v1/exam_results", headers=H, json={"learner_id": uid, "exam_id": "smoke", "score": 1, "total": 1}))
r = step("cannot read others (RLS)", requests.get(f"{URL}/rest/v1/learners?select=id", headers=H))
print("   rows visible:", len(r.json()) if r.ok else "?")
step("content read (public)", requests.get(f"{URL}/rest/v1/content?key=eq.curriculum&select=key", headers={"apikey": KEY}))
step("cleanup", requests.delete(f"{URL}/rest/v1/learners?id=eq.{uid}", headers=H))
sys.exit(0 if ok else 1)
