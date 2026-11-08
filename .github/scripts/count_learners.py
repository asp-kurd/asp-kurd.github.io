import os, requests
URL = "https://pecnuohpxraoxvfjsngm.supabase.co"; S = os.environ["SUPABASE_SERVICE_KEY"].strip()
H = {"apikey": S, "Authorization": f"Bearer {S}"}
rows = requests.get(f"{URL}/rest/v1/learners?select=name,email,xp,last_seen", headers=H).json()
real = [r for r in rows if r.get("name") != "SMOKE TEST"]
print(f"learners={len(real)} with_email={sum(1 for r in real if r.get('email'))} active_xp={sum(1 for r in real if (r.get('xp') or 0) > 0)}")
