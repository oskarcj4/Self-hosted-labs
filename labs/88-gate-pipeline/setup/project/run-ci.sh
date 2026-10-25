#!/usr/bin/env python3
"""Mini CI: jobs con continue-on-error y needs: [dep]."""
import os, re, subprocess, sys
from pathlib import Path

root = Path(__file__).resolve().parent
os.chdir(root)
text = (root / "pipeline.yml").read_text(encoding="utf-8")
jobs = {}
order = []
current = None
for line in text.splitlines():
    m = re.match(r"^  ([\w-]+):\s*$", line)
    if m:
        current = m.group(1)
        order.append(current)
        jobs[current] = {"continue_on_error": False, "needs": [], "run": None}
        continue
    if current is None:
        continue
    if re.match(r"^    continue-on-error:\s*true\b", line):
        jobs[current]["continue_on_error"] = True
    m = re.match(r"^    needs:\s*\[([^\]]*)\]\s*$", line)
    if m:
        jobs[current]["needs"] = [x.strip() for x in m.group(1).split(",") if x.strip()]
    m = re.match(r"^    run:\s*(.*)$", line)
    if m:
        jobs[current]["run"] = m.group(1).strip()

failed = set()
print("=== gate-ci ===")
for name in order:
    job = jobs[name]
    if not job["run"]:
        print(f"job {name}: sin run, skip")
        continue
    if any(dep in failed for dep in job["needs"]):
        print(f"job {name}: FAIL (needs {job['needs']} fallaron)")
        sys.exit(1)
    print(f"job {name}: {job['run']}")
    r = subprocess.run(job["run"], shell=True)
    if r.returncode != 0:
        if job["continue_on_error"]:
            print(f"job {name}: failed (continue-on-error)")
            failed.add(name)
        else:
            print(f"job {name}: FAIL")
            sys.exit(r.returncode)
    else:
        print(f"job {name}: ok")
sys.exit(0)
