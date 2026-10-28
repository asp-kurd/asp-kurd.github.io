"""خەلەتیێن build ـێ وەکی GitHub annotations دەردئێخیت (دشێن ب API بهێنە خواندن)."""
import re
import sys
from pathlib import Path

log = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines() if Path(sys.argv[1]).exists() else []
pat = re.compile(r"(error|Error|ERROR|FAILURE|What went wrong|Exception|Because |version solving failed|Could not)")


def esc(s: str) -> str:
    return s.replace("%", "%25").replace("\r", "").replace("\n", "%0A")


hits = [i for i, l in enumerate(log) if pat.search(l)]
blocks, seen = [], set()
for i in hits:
    lo, hi = max(0, i - 2), min(len(log), i + 6)
    if any(j in seen for j in range(lo, hi)):
        continue
    seen.update(range(lo, hi))
    blocks.append("\n".join(log[lo:hi]))

for b in blocks[:9]:
    print(f"::error title=build::{esc(b[:3500])}")
print(f"::error title=tail::{esc(chr(10).join(log[-60:])[-3500:])}")
