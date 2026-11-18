#!/usr/bin/env python3
"""Analiza los workflows de main de un repo de Gitea (pista Q).

Uso: wf.py REPO_BARE MARCA_DESPLIEGUE MARCA_TESTS [MARCA_TESTS...]
Imprime JSON:
  hay       hay algún workflow con un paso que contiene MARCA_DESPLIEGUE
  coe       algún workflow usa continue-on-error
  orden     el despliegue sólo corre tras un paso con alguna MARCA_TESTS
            (en el mismo job, antes, o en un job del que depende por needs)
  rama      el despliegue sólo ocurre desde main (disparador o if)
  previos   texto de todos los pasos que corren antes del despliegue
"""
import json
import subprocess
import sys

import yaml

bare, marca, tests = sys.argv[1], sys.argv[2], sys.argv[3:]


def git(*a):
    return subprocess.run(["git", "--git-dir", bare, *a], capture_output=True, text=True).stdout


def txt(x):
    return yaml.safe_dump(x, allow_unicode=True)


files = [f for f in git("ls-tree", "-r", "--name-only", "main").split("\n")
         if f.startswith((".github/workflows/", ".gitea/workflows/")) and f.endswith((".yml", ".yaml"))]
res = {"hay": False, "coe": False, "orden": False, "rama": False, "previos": ""}
for f in files:
    try:
        wf = yaml.safe_load(git("show", f"main:{f}")) or {}
    except Exception:
        continue
    on = wf.get("on", wf.get(True))
    jobs = wf.get("jobs") or {}
    if "continue-on-error" in txt(wf):
        res["coe"] = True

    def antes(nombre, vistos=None):
        vistos = set() if vistos is None else vistos
        n = (jobs.get(nombre) or {}).get("needs") or []
        for d in [n] if isinstance(n, str) else n:
            if d not in vistos:
                vistos.add(d)
                antes(d, vistos)
        return vistos

    for jn, j in jobs.items():
        steps = j.get("steps") or []
        idx = [i for i, s in enumerate(steps) if marca in txt(s)]
        if not idx:
            continue
        res["hay"] = True
        d = idx[0]
        cond = str(j.get("if", "")) + str(steps[d].get("if", ""))
        if "always()" in cond or "failure()" in cond:
            continue
        previos = [txt(s) for s in steps[:d]] + [txt(jobs[x]) for x in antes(jn) if x in jobs]
        res["previos"] = "\n".join(previos)
        res["orden"] = any(m in p for p in previos for m in tests)
        p = on.get("push") if isinstance(on, dict) else None
        solo = (isinstance(on, dict) and not (set(on) - {"push", "workflow_dispatch"})
                and isinstance(p, dict) and p.get("branches") in (["main"], "main"))
        res["rama"] = solo or ("refs/heads/main" in cond and "==" in cond)
print(json.dumps(res))
