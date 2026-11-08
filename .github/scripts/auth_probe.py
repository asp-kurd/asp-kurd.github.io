"""Probe: auth settings, anonymous → email/password link, password login, progress table. Cleans up."""
import os, sys, time, requests
URL = "https://pecnuohpxraoxvfjsngm.supabase.co"
KEY = "sb_publishable_btfzw-7Kc7ZJmfqvhPYr5w_ybgL55CJ"
SVC = (os.environ.get("SUPABASE_SERVICE_KEY") or "").strip()
def show(name, r):
    print(("✅" if r.status_code < 300 else "❌"), name, r.status_code, r.text[:260].replace("\n", " "))
    return r
s = requests.get(f"{URL}/auth/v1/settings", headers={"apikey": KEY}).json()
print("settings: mailer_autoconfirm=%s anonymous=%s email=%s disable_signup=%s" % (
    s.get("mailer_autoconfirm"), s.get("external", {}).get("anonymous_users"), s.get("external", {}).get("email"), s.get("disable_signup")))
r = show("anon signup", requests.post(f"{URL}/auth/v1/signup", headers={"apikey": KEY}, json={"data": {}}))
j = r.json(); tok = j["access_token"]; uid = j["user"]["id"]
H = {"apikey": KEY, "Authorization": f"Bearer {tok}", "Content-Type": "application/json"}
email = f"asp.probe.{int(time.time())}@gmail.com"
g = f"g{uid.replace('-', '')[:16]}@guest.asp-poya.com"
r = show("guest generated email", requests.put(f"{URL}/auth/v1/user", headers=H, json={"email": g, "password": "Guest#12345abc"}))
print("   email now:", r.json().get("email") if r.ok else None)
r = show("change to real email", requests.put(f"{URL}/auth/v1/user", headers=H, json={"email": email, "password": "Probe#12345"}))
if r.ok: print("   email now:", r.json().get("email"), "new_email:", r.json().get("new_email"))
r = show("password login", requests.post(f"{URL}/auth/v1/token?grant_type=password", headers={"apikey": KEY}, json={"email": email, "password": "Probe#12345"}))
if r.ok: print("   same user:", r.json()["user"]["id"] == uid)
show("progress upsert", requests.post(f"{URL}/rest/v1/progress", headers={**H, "Prefer": "resolution=merge-duplicates"}, json={"user_id": uid, "data": {"xp": 5}, "xp": 5}))
show("progress read", requests.get(f"{URL}/rest/v1/progress?user_id=eq.{uid}&select=xp", headers=H))
show("learners email column", requests.get(f"{URL}/rest/v1/learners?select=email&limit=1", headers=H))
if SVC:
    show("cleanup (admin delete user)", requests.delete(f"{URL}/auth/v1/admin/users/{uid}", headers={"apikey": SVC, "Authorization": f"Bearer {SVC}"}))
